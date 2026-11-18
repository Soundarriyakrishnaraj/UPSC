
-- ============================================================
-- UPSC PREPARATION APP
-- COMPLETE SECURE TEST SYSTEM MIGRATION
-- ============================================================
-- Uses existing public.admin_users table.
-- Preserves existing test, question, attempt and progress rows.
-- Does not drop existing test-system tables.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    subject TEXT NOT NULL,
    upsc_stage TEXT NOT NULL DEFAULT 'Prelims',
    stage_category TEXT NOT NULL,
    level_number INTEGER NOT NULL,
    test_number INTEGER NOT NULL DEFAULT 1,
    total_questions INTEGER NOT NULL,
    max_duration_minutes INTEGER NOT NULL,
    marks_per_question NUMERIC(5,2) NOT NULL DEFAULT 2.0,
    instructions TEXT,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.test_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID NOT NULL REFERENCES public.tests(id) ON DELETE CASCADE,
    question_number INTEGER NOT NULL,
    question_text TEXT NOT NULL,
    option_a TEXT NOT NULL,
    option_b TEXT NOT NULL,
    option_c TEXT NOT NULL,
    option_d TEXT NOT NULL,
    correct_option CHAR(1) NOT NULL
        CHECK (correct_option IN ('A','B','C','D')),
    explanation TEXT NOT NULL DEFAULT '',
    marks NUMERIC(5,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (test_id, question_number)
);

CREATE TABLE IF NOT EXISTS public.test_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID NOT NULL REFERENCES public.tests(id),
    student_id UUID NOT NULL REFERENCES auth.users(id),
    attempt_number INTEGER NOT NULL,
    selected_duration_minutes INTEGER NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deadline_at TIMESTAMPTZ NOT NULL,
    submitted_at TIMESTAMPTZ,
    is_submitted BOOLEAN NOT NULL DEFAULT FALSE,
    total_questions INTEGER NOT NULL,
    correct_count INTEGER,
    incorrect_count INTEGER,
    unanswered_count INTEGER,
    marks_obtained NUMERIC(14,6),
    negative_marks NUMERIC(14,6),
    max_marks NUMERIC(14,6),
    percentage NUMERIC(8,2),
    stars_earned INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (test_id, student_id, attempt_number)
);

CREATE TABLE IF NOT EXISTS public.test_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attempt_id UUID NOT NULL
        REFERENCES public.test_attempts(id) ON DELETE CASCADE,
    question_id UUID NOT NULL
        REFERENCES public.test_questions(id),
    selected_option CHAR(1)
        CHECK (selected_option IN ('A','B','C','D')),
    is_marked_for_review BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (attempt_id, question_id)
);

CREATE TABLE IF NOT EXISTS public.student_level_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id),
    test_id UUID NOT NULL REFERENCES public.tests(id),
    level_number INTEGER NOT NULL,
    is_unlocked BOOLEAN NOT NULL DEFAULT FALSE,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    best_stars INTEGER NOT NULL DEFAULT 0,
    best_score NUMERIC(14,6),
    best_attempt_id UUID REFERENCES public.test_attempts(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (student_id, test_id)
);

-- Upgrade numeric precision on existing installations.
ALTER TABLE public.test_attempts
    ALTER COLUMN marks_obtained TYPE NUMERIC(14,6),
    ALTER COLUMN negative_marks TYPE NUMERIC(14,6),
    ALTER COLUMN max_marks TYPE NUMERIC(14,6),
    ALTER COLUMN percentage TYPE NUMERIC(8,2);

ALTER TABLE public.student_level_progress
    ALTER COLUMN best_score TYPE NUMERIC(14,6);

-- ============================================================
-- 2. INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_tests_published
ON public.tests(is_published, is_archived, level_number);

CREATE INDEX IF NOT EXISTS idx_tests_stage_category
ON public.tests(upsc_stage, stage_category, level_number, test_number);

CREATE INDEX IF NOT EXISTS idx_test_questions_test
ON public.test_questions(test_id, question_number);

CREATE INDEX IF NOT EXISTS idx_test_attempts_student
ON public.test_attempts(student_id, test_id);

CREATE INDEX IF NOT EXISTS idx_test_attempts_deadline
ON public.test_attempts(deadline_at)
WHERE is_submitted = FALSE;

CREATE INDEX IF NOT EXISTS idx_test_answers_attempt
ON public.test_answers(attempt_id);

CREATE INDEX IF NOT EXISTS idx_level_progress_student
ON public.student_level_progress(student_id);

-- ============================================================
-- 3. TEST CONFIGURATION IMMUTABILITY
-- Once attempts exist, test configuration cannot be changed.
-- Publishing and archiving status may still be changed.
-- ============================================================

CREATE OR REPLACE FUNCTION public.guard_test_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF EXISTS (
            SELECT 1
            FROM public.test_attempts ta
            WHERE ta.test_id = OLD.id
        ) THEN
            IF ROW(
                NEW.title,
                NEW.description,
                NEW.subject,
                NEW.upsc_stage,
                NEW.stage_category,
                NEW.level_number,
                NEW.test_number,
                NEW.total_questions,
                NEW.max_duration_minutes,
                NEW.marks_per_question,
                NEW.instructions,
                NEW.created_by,
                NEW.created_at
            ) IS DISTINCT FROM ROW(
                OLD.title,
                OLD.description,
                OLD.subject,
                OLD.upsc_stage,
                OLD.stage_category,
                OLD.level_number,
                OLD.test_number,
                OLD.total_questions,
                OLD.max_duration_minutes,
                OLD.marks_per_question,
                OLD.instructions,
                OLD.created_by,
                OLD.created_at
            ) THEN
                RAISE EXCEPTION
                    'This test already has student attempts. Its configuration is locked. Create a new test version instead.';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_test_changes
ON public.tests;

CREATE TRIGGER trg_guard_test_changes
BEFORE UPDATE ON public.tests
FOR EACH ROW
EXECUTE FUNCTION public.guard_test_changes();

-- ============================================================
-- 4. QUESTION IMMUTABILITY
-- Questions can be edited only while the test is unpublished
-- and has no student attempts.
-- ============================================================

CREATE OR REPLACE FUNCTION public.guard_test_question_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_test_id UUID;
    v_published BOOLEAN;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_test_id := OLD.test_id;
    ELSE
        v_test_id := NEW.test_id;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.test_id <> OLD.test_id THEN
        RAISE EXCEPTION
            'Moving a question between tests is not allowed.';
    END IF;

    SELECT t.is_published
    INTO v_published
    FROM public.tests t
    WHERE t.id = v_test_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Test not found.';
    END IF;

    IF v_published THEN
        RAISE EXCEPTION
            'Unpublish this test before editing its questions.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.test_attempts ta
        WHERE ta.test_id = v_test_id
    ) THEN
        RAISE EXCEPTION
            'Questions cannot be changed because students have attempted this test. Create a new test version.';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_test_question_changes
ON public.test_questions;

CREATE TRIGGER trg_guard_test_question_changes
BEFORE INSERT OR UPDATE OR DELETE
ON public.test_questions
FOR EACH ROW
EXECUTE FUNCTION public.guard_test_question_changes();

-- ============================================================
-- 5. TEST PUBLICATION VALIDATION
-- Exact question count is mandatory.
-- ============================================================

CREATE OR REPLACE FUNCTION public.check_test_publish_validity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_q_count INTEGER;
    v_incomplete_count INTEGER;
BEGIN
    IF NEW.is_published = TRUE
       AND (
           TG_OP = 'INSERT'
           OR OLD.is_published = FALSE
       ) THEN

        IF NEW.total_questions <= 0 THEN
            RAISE EXCEPTION
                'Total questions must be greater than zero.';
        END IF;

        IF NEW.max_duration_minutes <= 0 THEN
            RAISE EXCEPTION
                'Maximum duration must be greater than zero.';
        END IF;

        IF NEW.marks_per_question <= 0 THEN
            RAISE EXCEPTION
                'Marks per question must be greater than zero.';
        END IF;

        IF NEW.level_number <= 0 OR NEW.test_number <= 0 THEN
            RAISE EXCEPTION
                'Level number and test number must be positive.';
        END IF;

        SELECT COUNT(*)
        INTO v_q_count
        FROM public.test_questions tq
        WHERE tq.test_id = NEW.id;

        IF v_q_count <> NEW.total_questions THEN
            RAISE EXCEPTION
                'Cannot publish: expected exactly % questions, found %.',
                NEW.total_questions, v_q_count;
        END IF;

        SELECT COUNT(*)
        INTO v_incomplete_count
        FROM public.test_questions tq
        WHERE tq.test_id = NEW.id
          AND (
              NULLIF(TRIM(tq.question_text), '') IS NULL
              OR NULLIF(TRIM(tq.option_a), '') IS NULL
              OR NULLIF(TRIM(tq.option_b), '') IS NULL
              OR NULLIF(TRIM(tq.option_c), '') IS NULL
              OR NULLIF(TRIM(tq.option_d), '') IS NULL
              OR tq.correct_option NOT IN ('A','B','C','D')
              OR NULLIF(TRIM(tq.explanation), '') IS NULL
              OR (tq.marks IS NOT NULL AND tq.marks <= 0)
          );

        IF v_incomplete_count > 0 THEN
            RAISE EXCEPTION
                'Cannot publish: % question(s) are incomplete.',
                v_incomplete_count;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_test_publish
ON public.tests;

CREATE TRIGGER trg_validate_test_publish
BEFORE INSERT OR UPDATE OF is_published
ON public.tests
FOR EACH ROW
EXECUTE FUNCTION public.check_test_publish_validity();

-- ============================================================
-- 6. START TEST ATTEMPT
-- Server-controlled duration, timer and progression.
-- ============================================================

CREATE OR REPLACE FUNCTION public.start_test_attempt(
    p_test_id UUID,
    p_duration_minutes INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_test public.tests%ROWTYPE;
    v_attempt public.test_attempts%ROWTYPE;
    v_new_attempt public.test_attempts%ROWTYPE;
    v_duration INTEGER;
    v_attempt_number INTEGER;
    v_q_count INTEGER;
    v_now TIMESTAMPTZ := NOW();
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Serialize simultaneous start requests for this student/test.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(
            p_test_id::TEXT || ':' || v_user_id::TEXT,
            0
        )
    );

    SELECT *
    INTO v_test
    FROM public.tests t
    WHERE t.id = p_test_id
    FOR SHARE;

    IF NOT FOUND OR NOT v_test.is_published OR v_test.is_archived THEN
        RAISE EXCEPTION 'Test is unavailable.';
    END IF;

    SELECT COUNT(*)
    INTO v_q_count
    FROM public.test_questions tq
    WHERE tq.test_id = p_test_id;

    IF v_q_count <> v_test.total_questions THEN
        RAISE EXCEPTION
            'Test configuration is invalid. Contact the administrator.';
    END IF;

    -- Level progression:
    -- Level 1, Test 1 is initially accessible.
    -- Other tests require an unlocked record or completion of
    -- the previous test/level in the same stage and category.
    IF NOT (
        v_test.level_number = 1
        AND v_test.test_number = 1
    ) AND NOT EXISTS (
        SELECT 1
        FROM public.student_level_progress p
        WHERE p.student_id = v_user_id
          AND p.test_id = p_test_id
          AND p.is_unlocked = TRUE
    ) AND NOT EXISTS (
        SELECT 1
        FROM public.student_level_progress p
        JOIN public.tests previous_test
          ON previous_test.id = p.test_id
        WHERE p.student_id = v_user_id
          AND p.is_completed = TRUE
          AND previous_test.upsc_stage = v_test.upsc_stage
          AND previous_test.stage_category = v_test.stage_category
          AND (
              previous_test.level_number = v_test.level_number - 1
              OR (
                  previous_test.level_number = v_test.level_number
                  AND previous_test.test_number < v_test.test_number
              )
          )
    ) THEN
        RAISE EXCEPTION
            'This level is locked. Complete the previous test first.';
    END IF;

    -- Resume existing active attempt instead of resetting timer.
    SELECT *
    INTO v_attempt
    FROM public.test_attempts ta
    WHERE ta.test_id = p_test_id
      AND ta.student_id = v_user_id
      AND ta.is_submitted = FALSE
    ORDER BY ta.attempt_number DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        IF v_now <= v_attempt.deadline_at THEN
            RETURN to_jsonb(v_attempt);
        END IF;

        -- Automatically submit expired attempt.
        PERFORM public.submit_test_attempt(v_attempt.id);
    END IF;

    IF p_duration_minutes IS NULL OR p_duration_minutes <= 0 THEN
        v_duration := v_test.max_duration_minutes;
    ELSE
        v_duration := LEAST(
            p_duration_minutes,
            v_test.max_duration_minutes
        );
    END IF;

    SELECT COALESCE(MAX(ta.attempt_number), 0) + 1
    INTO v_attempt_number
    FROM public.test_attempts ta
    WHERE ta.test_id = p_test_id
      AND ta.student_id = v_user_id;

    INSERT INTO public.test_attempts (
        test_id,
        student_id,
        attempt_number,
        selected_duration_minutes,
        started_at,
        deadline_at,
        is_submitted,
        total_questions,
        stars_earned
    )
    VALUES (
        p_test_id,
        v_user_id,
        v_attempt_number,
        v_duration,
        v_now,
        v_now + make_interval(mins => v_duration),
        FALSE,
        v_test.total_questions,
        0
    )
    RETURNING * INTO v_new_attempt;

    INSERT INTO public.student_level_progress (
        student_id,
        test_id,
        level_number,
        is_unlocked,
        is_completed,
        best_stars,
        best_score,
        updated_at
    )
    VALUES (
        v_user_id,
        p_test_id,
        v_test.level_number,
        TRUE,
        FALSE,
        0,
        NULL,
        v_now
    )
    ON CONFLICT (student_id, test_id)
    DO UPDATE SET
        is_unlocked = TRUE,
        updated_at = NOW();

    RETURN to_jsonb(v_new_attempt);
END;
$$;

-- ============================================================
-- 7. FETCH ACTIVE TEST QUESTIONS
-- Never returns correct answers or explanations.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_active_attempt_questions(
    p_attempt_id UUID
)
RETURNS TABLE (
    id UUID,
    test_id UUID,
    question_number INTEGER,
    question_text TEXT,
    option_a TEXT,
    option_b TEXT,
    option_c TEXT,
    option_d TEXT,
    marks NUMERIC(5,2)
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_test_id UUID;
BEGIN
    SELECT ta.test_id
    INTO v_test_id
    FROM public.test_attempts ta
    WHERE ta.id = p_attempt_id
      AND ta.student_id = auth.uid()
      AND ta.is_submitted = FALSE
      AND ta.deadline_at >= NOW();

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Attempt is expired, submitted, or does not belong to you.';
    END IF;

    RETURN QUERY
    SELECT
        tq.id,
        tq.test_id,
        tq.question_number,
        tq.question_text,
        tq.option_a,
        tq.option_b,
        tq.option_c,
        tq.option_d,
        tq.marks
    FROM public.test_questions tq
    WHERE tq.test_id = v_test_id
    ORDER BY tq.question_number;
END;
$$;

-- ============================================================
-- 8. SAVE ANSWER
-- Locks the attempt row, checks ownership and deadline.
-- ============================================================

CREATE OR REPLACE FUNCTION public.save_test_answer(
    p_attempt_id UUID,
    p_question_id UUID,
    p_selected_option CHAR(1),
    p_is_marked_for_review BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_attempt public.test_attempts%ROWTYPE;
    v_answer public.test_answers%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF p_selected_option IS NOT NULL
       AND p_selected_option NOT IN ('A','B','C','D') THEN
        RAISE EXCEPTION 'Invalid answer option.';
    END IF;

    -- Same row lock used by submit_test_attempt.
    SELECT *
    INTO v_attempt
    FROM public.test_attempts ta
    WHERE ta.id = p_attempt_id
      AND ta.student_id = auth.uid()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Attempt not found or access denied.';
    END IF;

    IF v_attempt.is_submitted THEN
        RAISE EXCEPTION 'This test has already been submitted.';
    END IF;

    IF NOW() > v_attempt.deadline_at THEN
        RAISE EXCEPTION 'The examination deadline has expired.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.test_questions tq
        WHERE tq.id = p_question_id
          AND tq.test_id = v_attempt.test_id
    ) THEN
        RAISE EXCEPTION 'Question does not belong to this test.';
    END IF;

    INSERT INTO public.test_answers (
        attempt_id,
        question_id,
        selected_option,
        is_marked_for_review,
        updated_at
    )
    VALUES (
        p_attempt_id,
        p_question_id,
        p_selected_option,
        COALESCE(p_is_marked_for_review, FALSE),
        NOW()
    )
    ON CONFLICT (attempt_id, question_id)
    DO UPDATE SET
        selected_option = EXCLUDED.selected_option,
        is_marked_for_review = EXCLUDED.is_marked_for_review,
        updated_at = NOW()
    RETURNING * INTO v_answer;

    RETURN jsonb_build_object(
        'id', v_answer.id,
        'attempt_id', v_answer.attempt_id,
        'question_id', v_answer.question_id,
        'selected_option', v_answer.selected_option,
        'is_marked_for_review', v_answer.is_marked_for_review
    );
END;
$$;

-- ============================================================
-- 9. SUBMIT AND SCORE TEST
-- Correct = +question marks
-- Wrong = -one-third of question marks
-- Unanswered = 0
-- ============================================================

CREATE OR REPLACE FUNCTION public.submit_test_attempt(
    p_attempt_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_attempt public.test_attempts%ROWTYPE;
    v_test public.tests%ROWTYPE;
    v_question RECORD;
    v_selected CHAR(1);

    v_correct INTEGER := 0;
    v_incorrect INTEGER := 0;
    v_unanswered INTEGER := 0;

    v_earned NUMERIC(14,6) := 0;
    v_negative NUMERIC(14,6) := 0;
    v_max NUMERIC(14,6) := 0;
    v_question_marks NUMERIC(14,6);
    v_final NUMERIC(14,6);
    v_percentage NUMERIC(8,2);
    v_stars INTEGER;

    v_next_test_id UUID;
    v_next_level INTEGER;
BEGIN
    SELECT *
    INTO v_attempt
    FROM public.test_attempts ta
    WHERE ta.id = p_attempt_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Attempt not found.';
    END IF;

    IF v_attempt.student_id <> auth.uid()
       AND NOT EXISTS (
           SELECT 1
           FROM public.admin_users au
           WHERE au.user_id = auth.uid()
       ) THEN
        RAISE EXCEPTION 'Access denied.';
    END IF;

    -- Idempotent: do not score a submitted attempt twice.
    IF v_attempt.is_submitted THEN
        RETURN jsonb_build_object(
            'attempt_id', v_attempt.id,
            'correct', v_attempt.correct_count,
            'incorrect', v_attempt.incorrect_count,
            'unanswered', v_attempt.unanswered_count,
            'marks_obtained', v_attempt.marks_obtained,
            'negative_marks', v_attempt.negative_marks,
            'max_marks', v_attempt.max_marks,
            'percentage', v_attempt.percentage,
            'stars', v_attempt.stars_earned,
            'is_submitted', TRUE
        );
    END IF;

    SELECT *
    INTO v_test
    FROM public.tests t
    WHERE t.id = v_attempt.test_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Test configuration not found.';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM public.test_questions tq
        WHERE tq.test_id = v_attempt.test_id
    ) <> v_attempt.total_questions THEN
        RAISE EXCEPTION
            'Question count changed unexpectedly. Contact administrator.';
    END IF;

    FOR v_question IN
        SELECT
            tq.id,
            tq.correct_option,
            COALESCE(tq.marks, v_test.marks_per_question)
                AS question_marks
        FROM public.test_questions tq
        WHERE tq.test_id = v_attempt.test_id
        ORDER BY tq.question_number
    LOOP
        v_question_marks := v_question.question_marks;
        v_max := v_max + v_question_marks;

        SELECT ta.selected_option
        INTO v_selected
        FROM public.test_answers ta
        WHERE ta.attempt_id = p_attempt_id
          AND ta.question_id = v_question.id;

        IF NOT FOUND OR v_selected IS NULL THEN
            v_unanswered := v_unanswered + 1;

        ELSIF v_selected = v_question.correct_option THEN
            v_correct := v_correct + 1;
            v_earned := v_earned + v_question_marks;

        ELSE
            v_incorrect := v_incorrect + 1;
            v_negative := v_negative + (
                v_question_marks / 3.0
            );
        END IF;
    END LOOP;

    v_final := ROUND(v_earned - v_negative, 6);

    IF v_max > 0 THEN
        v_percentage := ROUND((v_final / v_max) * 100, 2);
    ELSE
        v_percentage := 0;
    END IF;

    v_stars := CASE
        WHEN v_percentage >= 80 THEN 3
        WHEN v_percentage >= 60 THEN 2
        WHEN v_percentage >= 40 THEN 1
        ELSE 0
    END;

    UPDATE public.test_attempts
    SET
        is_submitted = TRUE,
        submitted_at = NOW(),
        correct_count = v_correct,
        incorrect_count = v_incorrect,
        unanswered_count = v_unanswered,
        marks_obtained = v_final,
        negative_marks = ROUND(v_negative, 6),
        max_marks = ROUND(v_max, 6),
        percentage = v_percentage,
        stars_earned = v_stars
    WHERE id = p_attempt_id;

    -- Preserve the actual best score, including negative scores.
    INSERT INTO public.student_level_progress (
        student_id,
        test_id,
        level_number,
        is_unlocked,
        is_completed,
        best_stars,
        best_score,
        best_attempt_id,
        updated_at
    )
    VALUES (
        v_attempt.student_id,
        v_attempt.test_id,
        v_test.level_number,
        TRUE,
        TRUE,
        v_stars,
        v_final,
        p_attempt_id,
        NOW()
    )
    ON CONFLICT (student_id, test_id)
    DO UPDATE SET
        is_completed = TRUE,
        best_stars = GREATEST(
            public.student_level_progress.best_stars,
            EXCLUDED.best_stars
        ),
        best_attempt_id = CASE
            WHEN public.student_level_progress.best_score IS NULL
              OR EXCLUDED.best_score >
                 public.student_level_progress.best_score
            THEN EXCLUDED.best_attempt_id
            ELSE public.student_level_progress.best_attempt_id
        END,
        best_score = CASE
            WHEN public.student_level_progress.best_score IS NULL
              OR EXCLUDED.best_score >
                 public.student_level_progress.best_score
            THEN EXCLUDED.best_score
            ELSE public.student_level_progress.best_score
        END,
        updated_at = NOW();

    -- Find the next test in the SAME stage and category.
    -- First unlock another test in the same level if one exists.
    SELECT t.id, t.level_number
    INTO v_next_test_id, v_next_level
    FROM public.tests t
    WHERE t.is_published = TRUE
      AND t.is_archived = FALSE
      AND t.upsc_stage = v_test.upsc_stage
      AND t.stage_category = v_test.stage_category
      AND (
          (
              t.level_number = v_test.level_number
              AND t.test_number > v_test.test_number
          )
          OR t.level_number = v_test.level_number + 1
      )
    ORDER BY
        t.level_number,
        t.test_number
    LIMIT 1;

    IF v_next_test_id IS NOT NULL THEN
        INSERT INTO public.student_level_progress (
            student_id,
            test_id,
            level_number,
            is_unlocked,
            is_completed,
            best_stars,
            best_score,
            updated_at
        )
        VALUES (
            v_attempt.student_id,
            v_next_test_id,
            v_next_level,
            TRUE,
            FALSE,
            0,
            NULL,
            NOW()
        )
        ON CONFLICT (student_id, test_id)
        DO UPDATE SET
            is_unlocked = TRUE,
            updated_at = NOW();
    END IF;

    RETURN jsonb_build_object(
        'attempt_id', p_attempt_id,
        'correct', v_correct,
        'incorrect', v_incorrect,
        'unanswered', v_unanswered,
        'marks_obtained', v_final,
        'negative_marks', ROUND(v_negative, 6),
        'max_marks', ROUND(v_max, 6),
        'percentage', v_percentage,
        'stars', v_stars,
        'is_submitted', TRUE
    );
END;
$$;

-- ============================================================
-- 10. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_level_progress ENABLE ROW LEVEL SECURITY;

-- TESTS

DROP POLICY IF EXISTS admin_all_tests
ON public.tests;

DROP POLICY IF EXISTS student_view_published_tests
ON public.tests;

CREATE POLICY admin_all_tests
ON public.tests
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.admin_users au
        WHERE au.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.admin_users au
        WHERE au.user_id = auth.uid()
    )
);

CREATE POLICY student_view_published_tests
ON public.tests
FOR SELECT TO authenticated
USING (
    is_published = TRUE
    AND is_archived = FALSE
);

-- QUESTIONS

DROP POLICY IF EXISTS admin_all_questions
ON public.test_questions;

DROP POLICY IF EXISTS admin_all_test_questions
ON public.test_questions;

DROP POLICY IF EXISTS student_view_questions
ON public.test_questions;

DROP POLICY IF EXISTS student_view_questions_after_submission
ON public.test_questions;

CREATE POLICY admin_all_test_questions
ON public.test_questions
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.admin_users au
        WHERE au.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.admin_users au
        WHERE au.user_id = auth.uid()
    )
);

-- Students can see question answer keys for review only when
-- they have submitted attempts and have no active attempt
-- for that test. Active retakes hide the question table.

CREATE POLICY student_view_questions_after_submission
ON public.test_questions
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.test_attempts ta
        WHERE ta.test_id = test_questions.test_id
          AND ta.student_id = auth.uid()
          AND ta.is_submitted = TRUE
    )
    AND NOT EXISTS (
        SELECT 1
        FROM public.test_attempts active_attempt
        WHERE active_attempt.test_id = test_questions.test_id
          AND active_attempt.student_id = auth.uid()
          AND active_attempt.is_submitted = FALSE
    )
);

-- ATTEMPTS

DROP POLICY IF EXISTS admin_view_all_attempts
ON public.test_attempts;

DROP POLICY IF EXISTS admin_all_test_attempts
ON public.test_attempts;

DROP POLICY IF EXISTS own_attempts
ON public.test_attempts;

DROP POLICY IF EXISTS student_select_own_attempts
ON public.test_attempts;

CREATE POLICY admin_all_test_attempts
ON public.test_attempts
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.admin_users au
        WHERE au.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.admin_users au
        WHERE au.user_id = auth.uid()
    )
);

CREATE POLICY student_select_own_attempts
ON public.test_attempts
FOR SELECT TO authenticated
USING (student_id = auth.uid());

-- ANSWERS

DROP POLICY IF EXISTS admin_all_test_answers
ON public.test_answers;

DROP POLICY IF EXISTS own_answers
ON public.test_answers;

DROP POLICY IF EXISTS student_select_own_answers
ON public.test_answers;

DROP POLICY IF EXISTS student_insert_active_answers
ON public.test_answers;

DROP POLICY IF EXISTS student_update_active_answers
ON public.test_answers;

CREATE POLICY admin_all_test_answers
ON public.test_answers
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.admin_users au
        WHERE au.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.admin_users au
        WHERE au.user_id = auth.uid()
    )
);

CREATE POLICY student_select_own_answers
ON public.test_answers
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.test_attempts ta
        WHERE ta.id = test_answers.attempt_id
          AND ta.student_id = auth.uid()
    )
);

-- PROGRESS

DROP POLICY IF EXISTS admin_view_progress
ON public.student_level_progress;

DROP POLICY IF EXISTS admin_all_level_progress
ON public.student_level_progress;

DROP POLICY IF EXISTS own_progress
ON public.student_level_progress;

DROP POLICY IF EXISTS student_select_own_progress
ON public.student_level_progress;

CREATE POLICY admin_all_level_progress
ON public.student_level_progress
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.admin_users au
        WHERE au.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.admin_users au
        WHERE au.user_id = auth.uid()
    )
);

CREATE POLICY student_select_own_progress
ON public.student_level_progress
FOR SELECT TO authenticated
USING (student_id = auth.uid());

-- ============================================================
-- 11. TABLE PERMISSIONS
-- ============================================================

REVOKE ALL ON public.tests,
    public.test_questions,
    public.test_attempts,
    public.test_answers,
    public.student_level_progress
FROM anon;

-- Admin CRUD is controlled by RLS on tests and questions.
GRANT SELECT, INSERT, UPDATE, DELETE
ON public.tests, public.test_questions
TO authenticated;

-- Students and admins may read attempts, answers and progress.
-- Writes are performed only through security-definer functions.
GRANT SELECT
ON public.test_attempts,
   public.test_answers,
   public.student_level_progress
TO authenticated;

REVOKE INSERT, UPDATE, DELETE
ON public.test_attempts,
   public.test_answers,
   public.student_level_progress
FROM authenticated, anon;

-- ============================================================
-- 12. FUNCTION PERMISSIONS
-- ============================================================

REVOKE ALL ON FUNCTION
public.start_test_attempt(UUID, INTEGER)
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION
public.get_active_attempt_questions(UUID)
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION
public.save_test_answer(UUID, UUID, CHAR, BOOLEAN)
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION
public.submit_test_attempt(UUID)
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION
public.check_test_publish_validity()
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION
public.guard_test_changes()
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION
public.guard_test_question_changes()
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
public.start_test_attempt(UUID, INTEGER)
TO authenticated;

GRANT EXECUTE ON FUNCTION
public.get_active_attempt_questions(UUID)
TO authenticated;

GRANT EXECUTE ON FUNCTION
public.save_test_answer(UUID, UUID, CHAR, BOOLEAN)
TO authenticated;

GRANT EXECUTE ON FUNCTION
public.submit_test_attempt(UUID)
TO authenticated;

-- Remove the old insecure fallback view, if it exists.
DROP VIEW IF EXISTS public.test_questions_for_attempt;

COMMIT;

-- ============================================================
-- END OF MIGRATION
-- ============================================================
