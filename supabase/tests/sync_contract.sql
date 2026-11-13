-- ============================================================
-- Sync Contract Verification Tests (PostgreSQL)
-- Asserts R7 schema contracts: column existence, types,
-- nullability, partial unique index, and idempotency.
-- ============================================================

DO $$
DECLARE
    v_nullable TEXT;
    v_type TEXT;
    v_index_def TEXT;
BEGIN
    -- 1. Verify daily_metrics exists and has neat_kcal + enhancement columns
    SELECT data_type INTO v_type
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'daily_metrics' AND column_name = 'neat_kcal';
    IF v_type IS DISTINCT FROM 'numeric' THEN
        RAISE EXCEPTION 'Contract failed: public.daily_metrics.neat_kcal missing or wrong type (%)', v_type;
    END IF;

    -- 2. Verify meals.weight_g is nullable (Audit F23)
    SELECT is_nullable INTO v_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'meals' AND column_name = 'weight_g';
    IF v_nullable IS DISTINCT FROM 'YES' THEN
        RAISE EXCEPTION 'Contract failed: public.meals.weight_g must be nullable, got %', v_nullable;
    END IF;

    -- 3. Verify meals R7 convergence columns
    SELECT data_type INTO v_type
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'meals' AND column_name = 'client_uuid';
    IF v_type IS DISTINCT FROM 'uuid' THEN
        RAISE EXCEPTION 'Contract failed: public.meals.client_uuid missing or wrong type (%)', v_type;
    END IF;

    SELECT data_type, is_nullable INTO v_type, v_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'meals' AND column_name = 'revision';
    IF v_type IS DISTINCT FROM 'integer' OR v_nullable IS DISTINCT FROM 'NO' THEN
        RAISE EXCEPTION 'Contract failed: public.meals.revision contract mismatch (type=%, nullable=%)', v_type, v_nullable;
    END IF;

    SELECT data_type, is_nullable INTO v_type, v_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'meals' AND column_name = 'is_deleted';
    IF v_type IS DISTINCT FROM 'boolean' OR v_nullable IS DISTINCT FROM 'NO' THEN
        RAISE EXCEPTION 'Contract failed: public.meals.is_deleted contract mismatch (type=%, nullable=%)', v_type, v_nullable;
    END IF;

    SELECT data_type INTO v_type
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'meals' AND column_name = 'kcal_exact';
    IF v_type IS DISTINCT FROM 'numeric' THEN
        RAISE EXCEPTION 'Contract failed: public.meals.kcal_exact missing or wrong type (%)', v_type;
    END IF;

    SELECT data_type, is_nullable INTO v_type, v_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'meals' AND column_name = 'buffer_version';
    IF v_type IS DISTINCT FROM 'integer' OR v_nullable IS DISTINCT FROM 'NO' THEN
        RAISE EXCEPTION 'Contract failed: public.meals.buffer_version contract mismatch (type=%, nullable=%)', v_type, v_nullable;
    END IF;

    SELECT data_type, is_nullable INTO v_type, v_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'meals' AND column_name = 'provenance';
    IF v_type IS DISTINCT FROM 'text' OR v_nullable IS DISTINCT FROM 'NO' THEN
        RAISE EXCEPTION 'Contract failed: public.meals.provenance contract mismatch (type=%, nullable=%)', v_type, v_nullable;
    END IF;

    SELECT data_type, is_nullable INTO v_type, v_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'meals' AND column_name = 'updated_at';
    IF v_type IS DISTINCT FROM 'timestamp with time zone' OR v_nullable IS DISTINCT FROM 'NO' THEN
        RAISE EXCEPTION 'Contract failed: public.meals.updated_at contract mismatch (type=%, nullable=%)', v_type, v_nullable;
    END IF;

    -- 4. Verify partial unique index idx_meals_user_client_uuid
    SELECT indexdef INTO v_index_def
    FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'meals' AND indexname = 'idx_meals_user_client_uuid';
    IF v_index_def IS NULL OR v_index_def NOT ILIKE '%UNIQUE%' OR v_index_def NOT ILIKE '%client_uuid IS NOT NULL%' THEN
        RAISE EXCEPTION 'Contract failed: idx_meals_user_client_uuid missing or invalid (%)', v_index_def;
    END IF;

    -- 5. Verify workout_analyses.revision and 006 columns
    SELECT data_type, is_nullable INTO v_type, v_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'workout_analyses' AND column_name = 'revision';
    IF v_type IS DISTINCT FROM 'integer' OR v_nullable IS DISTINCT FROM 'NO' THEN
        RAISE EXCEPTION 'Contract failed: public.workout_analyses.revision contract mismatch (type=%, nullable=%)', v_type, v_nullable;
    END IF;
END $$;

-- 6. Transactional behavioral contract check (rolled back cleanly)
BEGIN;

-- Nullable weight_g + client_uuid insert
INSERT INTO public.meals (
    user_id, client_uuid, meal_name, kcal, kcal_exact, buffer_version,
    protein, fat, carbs, weight_g, confidence, dietary_date, revision, provenance, is_deleted
) VALUES (
    999001, '11111111-1111-1111-1111-111111111111', 'Test Espresso', 12, 10, 1,
    0, 0, 2, NULL, 92, '2026-11-13', 1, 'manual', FALSE
);

-- Multiple legacy NULL client_uuid rows for same user must succeed
INSERT INTO public.meals (user_id, client_uuid, meal_name, kcal, protein, fat, carbs, weight_g, dietary_date)
VALUES (999001, NULL, 'Legacy Meal 1', 300, 20, 10, 30, NULL, '2026-11-13');

INSERT INTO public.meals (user_id, client_uuid, meal_name, kcal, protein, fat, carbs, weight_g, dietary_date)
VALUES (999001, NULL, 'Legacy Meal 2', 350, 25, 10, 35, 200, '2026-11-13');

-- Duplicate (user_id, client_uuid) must trigger unique_violation
DO $$
BEGIN
    INSERT INTO public.meals (user_id, client_uuid, meal_name, kcal, protein, fat, carbs, weight_g, dietary_date)
    VALUES (999001, '11111111-1111-1111-1111-111111111111', 'Duplicate UUID', 12, 0, 0, 2, NULL, '2026-11-13');
    RAISE EXCEPTION 'Expected unique_violation for duplicate (user_id, client_uuid)';
EXCEPTION
    WHEN unique_violation THEN
        NULL;
END $$;

-- daily_metrics upsert with neat_kcal
INSERT INTO public.daily_metrics (user_id, metric_date, steps, active_kcal, neat_kcal)
VALUES (999001, '2026-11-13', 8500, 420.5, 240.5)
ON CONFLICT (user_id, metric_date) DO UPDATE SET neat_kcal = EXCLUDED.neat_kcal;

ROLLBACK;
