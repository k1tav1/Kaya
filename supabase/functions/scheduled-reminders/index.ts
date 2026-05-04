import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (_req) => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const today = new Date();
    const threeDaysFromNow = new Date(today);
    threeDaysFromNow.setDate(today.getDate() + 3);
    const dateStr = threeDaysFromNow.toISOString().split("T")[0];

    const { data: meetings } = await supabase
      .from("meetings")
      .select("id, title, meeting_date, created_by")
      .eq("meeting_date", dateStr)
      .eq("status", "published");

    const notifications = [];

    for (const meeting of meetings ?? []) {
      const { data: devices } = await supabase
        .from("member_devices")
        .select("fcm_token")
        .eq("notifications_enabled", true);

      for (const device of devices ?? []) {
        notifications.push({
          token: device.fcm_token,
          title: "Upcoming Meeting",
          body: `${meeting.title} is scheduled in 3 days`,
        });
      }
    }

    const { data: loans } = await supabase
      .from("loan_requests")
      .select("id, member_id, approved_amount, due_date")
      .eq("status", "approved")
      .eq("due_date", dateStr);

    for (const loan of loans ?? []) {
      const { data: devices } = await supabase
        .from("member_devices")
        .select("fcm_token")
        .eq("member_id", loan.member_id)
        .eq("notifications_enabled", true);

      for (const device of devices ?? []) {
        notifications.push({
          token: device.fcm_token,
          title: "Loan Repayment Due",
          body: `Your loan repayment of KES ${loan.approved_amount} is due in 3 days`,
        });
      }
    }

    const fcmKey = Deno.env.get("FCM_SERVER_KEY");
    const results = [];

    for (const notif of notifications) {
      if (!fcmKey) break;
      const res = await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Authorization": `key=${fcmKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          to: notif.token,
          notification: { title: notif.title, body: notif.body },
        }),
      });
      results.push(await res.json());
    }

    return new Response(
      JSON.stringify({ success: true, sent: notifications.length, results }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
