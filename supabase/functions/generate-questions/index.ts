// Supabase Edge Function: generates multiple-choice quiz questions with a free Gemini model.
//
// Request (POST, JSON, user must be signed in):  { "topic": "Human anatomy", "difficulty": 2, "count": 10 }
// Response: { "questions": [ { "question", "options": [4 strings], "correct_index", "category", "difficulty" } ] }
//
// Secrets (Supabase Dashboard -> Edge Functions -> Secrets, or `supabase secrets set`):
//   GEMINI_API_KEY  - free key from https://aistudio.google.com/apikey
//   GEMINI_MODEL    - optional, defaults to gemini-2.5-flash-lite

const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash-lite";
const DIFFICULTY_NAMES = ["", "easy", "medium", "hard"];

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

interface Question {
  question: string;
  options: string[];
  correct_index: number;
  category: string;
  difficulty: number;
}

/** Keeps only well-formed questions (4 distinct options, valid correct index). */
function validate(items: unknown, difficulty: number, topic: string): Question[] {
  if (!Array.isArray(items)) return [];
  const result: Question[] = [];

  for (const item of items) {
    const question = typeof item?.question === "string" ? item.question.trim() : "";
    const options = Array.isArray(item?.options) ? item.options.map((o: unknown) => String(o).trim()) : [];
    const correct = item?.correct_index;

    if (!question || options.length !== 4) continue;
    if (new Set(options).size !== 4 || options.some((o: string) => !o)) continue;
    if (!Number.isInteger(correct) || correct < 0 || correct > 3) continue;

    result.push({ question, options, correct_index: correct, category: topic, difficulty });
  }
  return result;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply({ error: "Use POST." }, 405);

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return reply({ error: "AI is not configured on the server (missing GEMINI_API_KEY)." }, 500);

  let body: { topic?: unknown; difficulty?: unknown; count?: unknown };
  try {
    body = await req.json();
  } catch {
    return reply({ error: "Invalid request." }, 400);
  }

  const topic = typeof body.topic === "string" ? body.topic.trim().slice(0, 100) : "";
  const difficulty = Math.min(3, Math.max(1, Number(body.difficulty) || 2));
  const count = Math.min(20, Math.max(1, Number(body.count) || 10));
  if (topic.length < 3) return reply({ error: "Describe the topic (at least 3 characters)." }, 400);

  const prompt = `Write ${count} multiple-choice quiz questions in English about: "${topic}".
Difficulty: ${DIFFICULTY_NAMES[difficulty]}.
Rules:
- exactly 4 distinct answer options per question, exactly one correct;
- the correct answer must be factually accurate and unambiguous;
- vary the position of the correct option;
- keep questions and options short.
Return ONLY a JSON array, no text around it. Each item: {"question": string, "options": [string, string, string, string], "correct_index": number 0-3}.`;

  let response: Response;
  try {
    response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { responseMimeType: "application/json", temperature: 0.8 },
      }),
    });
  } catch {
    return reply({ error: "Could not reach the AI service." }, 502);
  }

  if (!response.ok) {
    const status = response.status === 429 ? 429 : 502;
    const message = response.status === 429
      ? "The free AI limit was reached. Try again in a minute."
      : "The AI service returned an error.";
    return reply({ error: message }, status);
  }

  try {
    const data = await response.json();
    const text: string = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "[]";
    const questions = validate(JSON.parse(text), difficulty, topic);
    if (questions.length === 0) return reply({ error: "The AI did not return usable questions. Try again." }, 502);
    return reply({ questions });
  } catch {
    return reply({ error: "The AI answer could not be read. Try again." }, 502);
  }
});
