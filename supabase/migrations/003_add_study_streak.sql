-- 003_add_study_streak.sql
-- Migration to add secure daily study streak tracking.
-- This migration creates a table to record per‑student study days,
-- an RPC for safely inserting a study day, and a view that computes
-- the current and longest streaks for the authenticated student.
-- All operations are idempotent and respect RLS policies.

-- 1. Table definition -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_study_days (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    day DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Unique constraint to prevent duplicate days per student
CREATE UNIQUE INDEX IF NOT EXISTS uq_student_study_days_student_day
    ON public.student_study_days (student_id, day);

-- 2. Row‑level security ----------------------------------------------------
ALTER TABLE public.student_study_days ENABLE ROW LEVEL SECURITY;

-- SELECT policy: students can read only their own rows
CREATE POLICY select_own_study_days ON public.student_study_days
    FOR SELECT USING (auth.uid() = student_id);

-- No INSERT/UPDATE/DELETE policies for the "authenticated" role –
-- inserts must go through the secure RPC only.

-- 3. Secure RPC ------------------------------------------------------------
-- This function records a study day for the current authenticated user.
-- It derives the student id from auth.uid() and uses the server's current
-- timestamp (now()) converted to the Asia/Kolkata calendar date.
-- The function is SECURITY DEFINER so it can bypass RLS for the insert,
-- but it sets a safe search_path.

CREATE OR REPLACE FUNCTION public.record_study_day()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    student_uuid UUID := auth.uid();
    study_day DATE := (now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
    IF student_uuid IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated request to record_study_day';
    END IF;

    INSERT INTO public.student_study_days (student_id, day)
    VALUES (student_uuid, study_day)
    ON CONFLICT (student_id, day) DO NOTHING;
END;
$$;

-- Grant execution only to authenticated users (no anon access)
GRANT EXECUTE ON FUNCTION public.record_study_day() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.record_study_day() FROM anon;

-- 4. Streak view ------------------------------------------------------------
-- The view returns the current streak (0 if no recent activity) and the
-- longest streak for the calling student.  It uses explicit timezone
-- conversion to Asia/Kolkata and works even if a student has no rows.

CREATE OR REPLACE VIEW public.student_streaks AS
SELECT
    student_id,
    -- Longest streak ever recorded
    COALESCE(
        (SELECT MAX(streak_len) FROM (
            SELECT COUNT(*) AS streak_len
            FROM (
                SELECT day,
                       day - (ROW_NUMBER() OVER (ORDER BY day)) * INTERVAL '1 day' AS grp
                FROM public.student_study_days
                WHERE student_id = s.student_id
            ) sub
            GROUP BY grp
        ) gaps),
        0
    ) AS longest_streak,
    -- Current streak (0 if the most recent day is older than yesterday)
    COALESCE(
        (SELECT COUNT(*) FROM (
            SELECT day,
                   day - (ROW_NUMBER() OVER (ORDER BY day)) * INTERVAL '1 day' AS grp
            FROM public.student_study_days
            WHERE student_id = s.student_id
        ) sub
        WHERE day >= (now() AT TIME ZONE 'Asia/Kolkata')::date - INTERVAL '1 day'
        GROUP BY grp
        ORDER BY MAX(day) DESC
        LIMIT 1),
        0
    ) AS current_streak,
    -- Today's study status (true if a row exists for today)
    EXISTS (
        SELECT 1 FROM public.student_study_days
        WHERE student_id = s.student_id
          AND day = (now() AT TIME ZONE 'Asia/Kolkata')::date
    ) AS studied_today
FROM (
    SELECT DISTINCT student_id FROM public.student_study_days
) s;

-- RLS on the view – students can only see their own row
ALTER VIEW public.student_streaks ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_own_streak ON public.student_streaks
    FOR SELECT USING (auth.uid() = student_id);

-- 5. Test attempts count view (optional helper) ----------------------------
-- This view provides the total number of successfully submitted test attempts
-- for each student.  It assumes the table `test_attempts` has a boolean column
-- `is_submitted` that is true only for completed attempts.

CREATE OR REPLACE VIEW public.student_test_counts AS
SELECT
    attemp.student_id,
    COUNT(*) AS completed_tests
FROM public.test_attempts attemp
WHERE attemp.is_submitted = true
GROUP BY attemp.student_id;

ALTER VIEW public.student_test_counts ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_own_test_counts ON public.student_test_counts
    FOR SELECT USING (auth.uid() = student_id);

-- End of migration
