import "dotenv/config";
import { supabase } from "../lib/supabase.js";

const { count, error } = await supabase
  .from("users")
  .select("id", { count: "exact", head: true })
  .limit(0);

if (error) {
  console.error(`Could not read public.users (${error.code}): ${error.message}`);
  process.exitCode = 1;
} else {
  console.log(`public.users is reachable. Current row count: ${count ?? 0}`);
}
