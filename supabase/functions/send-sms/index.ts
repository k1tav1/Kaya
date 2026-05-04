import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  try {
    const { phone, message } = await req.json();

    const apiKey = Deno.env.get("AT_API_KEY");
    const username = Deno.env.get("AT_USERNAME");

    if (!apiKey || !username) {
      return new Response(JSON.stringify({ error: "AT credentials not set" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const params = new URLSearchParams({
      username,
      to: phone,
      message,
    });

    const res = await fetch("https://api.africastalking.com/version1/messaging", {
      method: "POST",
      headers: {
        "apiKey": apiKey,
        "Content-Type": "application/x-www-form-urlencoded",
        "Accept": "application/json",
      },
      body: params.toString(),
    });

    const result = await res.json();

    return new Response(JSON.stringify({ success: true, result }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
