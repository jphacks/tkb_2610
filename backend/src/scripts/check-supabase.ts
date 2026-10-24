import "dotenv/config";

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseSecretKey = process.env.SUPABASE_SECRET_KEY;

if (!supabaseUrl || !supabaseSecretKey) {
  console.error("Missing SUPABASE_URL or SUPABASE_SECRET_KEY in backend/.env");
  process.exitCode = 1;
} else {
  try {
    const response = await fetch(`${supabaseUrl.replace(/\/$/, "")}/rest/v1/`, {
      headers: { apikey: supabaseSecretKey },
    });

    if (!response.ok) {
      console.error(`Supabase responded with HTTP ${response.status}. Check the URL and secret key.`);
      process.exitCode = 1;
    } else {
      console.log(`Supabase REST API is reachable (HTTP ${response.status}).`);
    }
  } catch {
    console.error("Could not reach Supabase. Check the URL and network connection.");
    process.exitCode = 1;
  }
}
