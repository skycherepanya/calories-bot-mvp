-- ============================================================
-- RLS & Account Ownership Contract Verification Tests
-- Asserts R8 schema contracts: auth_user_id columns,
-- user_account_mappings table, RLS enablement, anon denial,
-- User A own access, and User B cross-user isolation.
-- ============================================================

DO $$
DECLARE
    v_type TEXT;
    v_rls_enabled BOOLEAN;
    v_table TEXT;
    c_tables TEXT[] := ARRAY[
        'meals',
        'workout_analyses',
        'daily_metrics',
        'sleep_logs',
        'workouts',
        'body_measurements',
        'activities'
    ];
BEGIN
    -- 1. Verify auth_user_id UUID columns on all 7 tables
    FOREACH v_table IN ARRAY c_tables LOOP
        SELECT data_type INTO v_type
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = v_table AND column_name = 'auth_user_id';

        IF v_type IS DISTINCT FROM 'uuid' THEN
            RAISE EXCEPTION 'Contract failed: public.%.auth_user_id missing or wrong type (%)', v_table, v_type;
        END IF;

        -- Verify RLS is enabled on each table
        SELECT relrowsecurity INTO v_rls_enabled
        FROM pg_class
        WHERE relname = v_table AND relnamespace = 'public'::regnamespace;

        IF v_rls_enabled IS NOT TRUE THEN
            RAISE EXCEPTION 'Contract failed: RLS must be enabled on public.%', v_table;
        END IF;
    END LOOP;

    -- 2. Verify user_account_mappings table and RLS
    SELECT relrowsecurity INTO v_rls_enabled
    FROM pg_class
    WHERE relname = 'user_account_mappings' AND relnamespace = 'public'::regnamespace;

    IF v_rls_enabled IS NOT TRUE THEN
        RAISE EXCEPTION 'Contract failed: RLS must be enabled on public.user_account_mappings';
    END IF;

    SELECT data_type INTO v_type
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_account_mappings' AND column_name = 'auth_user_id';
    IF v_type IS DISTINCT FROM 'uuid' THEN
        RAISE EXCEPTION 'Contract failed: public.user_account_mappings.auth_user_id must be uuid, got %', v_type;
    END IF;

    SELECT data_type INTO v_type
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_account_mappings' AND column_name = 'legacy_user_id';
    IF v_type IS DISTINCT FROM 'bigint' THEN
        RAISE EXCEPTION 'Contract failed: public.user_account_mappings.legacy_user_id must be bigint, got %', v_type;
    END IF;
END $$;

-- 3. Behavioral verification in an isolated rolled-back transaction
BEGIN;

-- Helper UUIDs
-- User A: 'a0000000-0000-0000-0000-000000000001'
-- User B: 'b0000000-0000-0000-0000-000000000002'

-- Mock auth helper function if not present in testing environment
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION auth.role() RETURNS TEXT AS $$
    SELECT COALESCE(NULLIF(current_setting('request.jwt.claim.role', true), ''), 'anon');
$$ LANGUAGE sql STABLE;

-- Test Scenario A: User A inserts and reads their own meal (including via DEFAULT auth.uid())
SET LOCAL "request.jwt.claim.role" = 'authenticated';
SET LOCAL "request.jwt.claim.sub" = 'a0000000-0000-0000-0000-000000000001';

INSERT INTO public.meals (
    user_id, client_uuid, meal_name, kcal,
    protein, fat, carbs, weight_g, dietary_date, revision
) VALUES (
    472025574, 'a1111111-1111-1111-1111-111111111111',
    'User A Oatmeal', 360, 20, 8, 52, 250, '2026-11-13', 1
);

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM public.meals
    WHERE client_uuid = 'a1111111-1111-1111-1111-111111111111';

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Contract failed: User A should read their own inserted meal, got count %', v_count;
    END IF;
END $$;

-- Test Scenario B: User B cannot read, update, or delete User A's meal
SET LOCAL "request.jwt.claim.role" = 'authenticated';
SET LOCAL "request.jwt.claim.sub" = 'b0000000-0000-0000-0000-000000000002';

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM public.meals
    WHERE client_uuid = 'a1111111-1111-1111-1111-111111111111';

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Contract failed: User B read User A meal! Isolation breach (count=%)', v_count;
    END IF;
END $$;

-- User B attempting to spoof User A's auth_user_id on INSERT must fail RLS WITH CHECK
DO $$
BEGIN
    INSERT INTO public.meals (
        user_id, auth_user_id, client_uuid, meal_name, kcal,
        protein, fat, carbs, weight_g, dietary_date, revision
    ) VALUES (
        472025574, 'a0000000-0000-0000-0000-000000000001', 'b2222222-2222-2222-2222-222222222222',
        'Spoofed Meal', 300, 15, 5, 45, 200, '2026-11-13', 1
    );
    RAISE EXCEPTION 'Contract failed: User B should be denied inserting meal with User A auth_user_id';
EXCEPTION
    WHEN insufficient_privilege OR check_violation THEN
        -- Expected RLS policy rejection
        NULL;
END $$;

-- User B attempting to self-assign legacy_user_id in user_account_mappings must fail RLS
DO $$
BEGIN
    INSERT INTO public.user_account_mappings (auth_user_id, legacy_user_id)
    VALUES ('b0000000-0000-0000-0000-000000000002', 472025574);
    RAISE EXCEPTION 'Contract failed: Authenticated client must not be able to self-insert user_account_mappings';
EXCEPTION
    WHEN insufficient_privilege OR check_violation THEN
        NULL;
END $$;

-- Test Scenario C: Anon role denial
SET LOCAL "request.jwt.claim.role" = 'anon';
SET LOCAL "request.jwt.claim.sub" = '';

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM public.meals;

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Contract failed: Anon role read % rows, expected 0 (anon denial)', v_count;
    END IF;
END $$;

DO $$
BEGIN
    INSERT INTO public.meals (
        user_id, auth_user_id, client_uuid, meal_name, kcal,
        protein, fat, carbs, weight_g, dietary_date, revision
    ) VALUES (
        472025574, 'a0000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333',
        'Anon Meal', 300, 15, 5, 45, 200, '2026-11-13', 1
    );
    RAISE EXCEPTION 'Contract failed: Anon role insert should be denied by RLS';
EXCEPTION
    WHEN insufficient_privilege OR check_violation THEN
        -- Expected RLS policy rejection for anon
        NULL;
END $$;

ROLLBACK;
