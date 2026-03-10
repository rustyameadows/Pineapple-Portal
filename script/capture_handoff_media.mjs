import fs from "node:fs/promises";
import path from "node:path";
import { chromium } from "playwright";

const baseUrl = process.env.HANDOFF_BASE_URL || "http://127.0.0.1:3000";
const plannerEmail = process.env.HANDOFF_PLANNER_EMAIL || "ada@example.com";
const plannerPassword = process.env.HANDOFF_PLANNER_PASSWORD || "password123";

const outputDir = path.resolve("docs/handoff/media");

const shots = [
  { name: "01-planner-dashboard.png", url: "/", waitFor: "text=Events" },
  { name: "02-global-vendors.png", url: "/settings/global_vendors", waitFor: "text=Global Vendors" },
  { name: "03-global-locations.png", url: "/settings/global_venues", waitFor: "text=Global Locations" },
  { name: "04-ros-table.png", url: "/events/1/calendar", waitFor: "text=Run of Show" },
  { name: "05-ros-item-edit.png", url: "/events/1/calendar/items/1/edit", waitFor: "text=Edit" },
  { name: "06-decision-calendar.png", url: "/events/1/calendars", waitFor: "text=Decision Calendar" },
  { name: "07-approvals.png", url: "/events/1/approvals", waitFor: "text=Approvals" },
  { name: "08-payments.png", url: "/events/1/payments", waitFor: "text=Payments" },
  { name: "09-client-dashboard.png", url: "/client/harper-rivera-wedding", waitFor: "text=Wedding" }
];

await fs.mkdir(outputDir, { recursive: true });

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width: 1680, height: 1000 } });
const page = await context.newPage();

await page.goto(`${baseUrl}/login`, { waitUntil: "networkidle" });
await page.fill('input[name="email"]', plannerEmail);
await page.fill('input[name="password"]', plannerPassword);
await page.click('button[type="submit"]');
await page.waitForLoadState("networkidle");

for (const shot of shots) {
  await page.goto(`${baseUrl}${shot.url}`, { waitUntil: "networkidle" });
  await page.waitForSelector(shot.waitFor, { timeout: 10000 });
  await page.screenshot({ path: path.join(outputDir, shot.name), fullPage: true });
  console.log(`Captured ${shot.name}`);
}

await browser.close();
