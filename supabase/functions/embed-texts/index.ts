// Supabase Edge Function: turns texts into embeddings (vectors of numbers describing their meaning).
// Uses the model built into Supabase Edge Functions (gte-small, 384 numbers per text) - free, no API key needed.
//
// Request (POST, JSON, user must be signed in):  { "texts": ["term definition", "player's answer", ...] }
// Response: { "embeddings": [[0.01, -0.02, ...], ...] }   (same order as "texts", vectors are normalized)
//
// The app compares the vectors with cosine similarity to see whose answer is closest to the reference.

// The `Supabase.ai` global exists only inside the Supabase Edge Runtime.
declare const Supabase: {
  ai: { Session: new (model: string) => { run(input: string, options?: Record<string, unknown>): Promise<ArrayLike<number>> } };
};

const MAX_TEXTS = 10;
const MAX_LENGTH = 500;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function reply(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const model = new Supabase.ai.Session("gte-small");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply({ error: "Use POST." }, 405);

  let texts: unknown;
  try {
    texts = (await req.json()).texts;
  } catch {
    return reply({ error: "Invalid request." }, 400);
  }

  if (!Array.isArray(texts) || texts.length === 0 || texts.length > MAX_TEXTS) {
    return reply({ error: `Send between 1 and ${MAX_TEXTS} texts.` }, 400);
  }
  if (texts.some((t) => typeof t !== "string" || t.trim() === "" || t.length > MAX_LENGTH)) {
    return reply({ error: `Each text must be 1-${MAX_LENGTH} characters.` }, 400);
  }

  try {
    const embeddings: number[][] = [];
    for (const text of texts as string[]) {
      const vector = await model.run(text.trim(), { mean_pool: true, normalize: true });
      embeddings.push(Array.from(vector, (n) => Math.round(n * 1e5) / 1e5));
    }
    return reply({ embeddings });
  } catch {
    return reply({ error: "Could not compute embeddings." }, 500);
  }
});
