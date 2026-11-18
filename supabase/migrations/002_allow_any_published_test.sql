-- supabase/migrations/002_allow_any_published_test.sql
-- ============================================================
-- MIGRATION: Allow Students to Attempt Any Published Test
-- 
-- Changes:
-- 1. Removes sequential level completion requirement in start_test_attempt()
--    so students can attempt any published test in any order.
-- 2. Preserves server-side duration cap, timer deadline enforcement,
--    active-attempt resumption, concurrency locks, and attempt isolation.
-- 3. Keeps input parameter signature: (p_test_id UUID, p_duration_minutes INTEGER)
--    which matches Flutter TestService.startAttempt(testId, durationMinutes).
-- 4. Automatically records unlocked progress for the attempted test.
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

    -- Enforce duration: cannot exceed administrator-configured maximum.
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

    -- Record progress record so student level progress tracks this attempt.
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

-- Ensure permissions remain correctly assigned
REVOKE ALL ON FUNCTION public.start_test_attempt(UUID, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_test_attempt(UUID, INTEGER) TO authenticated;

