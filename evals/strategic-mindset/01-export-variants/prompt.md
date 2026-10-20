---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
We shipped the order export feature last quarter on a tight deadline. It works and customers use it every day. Before we plan next quarter: is this code holding up, or should we be worried about it?

```ts
// reports/orderExport.ts
import { db } from "../db";
import { formatMoney } from "../money";
import { ACME_ORG_ID, GLOBEX_ORG_ID } from "../orgs";

export interface ExportRequest {
  orgId: string;
  from: Date;
  to: Date;
  forExcel: boolean;
}

export async function exportOrdersCsv(orgId: string, from: Date, to: Date): Promise<string> {
  const orders = await db.orders.findMany({
    where: { orgId, createdAt: { gte: from, lt: to } },
    orderBy: { createdAt: "asc" },
  });
  const lines = [["Order ID", "Date", "Customer", "Total", "Status"].join(",")];
  for (const o of orders) {
    lines.push(
      [o.id, o.createdAt.toISOString(), `"${o.customerName}"`, formatMoney(o.totalCents, o.currency), o.status].join(","),
    );
  }
  return lines.join("\n");
}

// Acme's ERP import wants semicolons and their PO number.
// TODO: fold into exportOrdersCsv after the Q3 launch
export async function exportOrdersCsvAcme(orgId: string, from: Date, to: Date): Promise<string> {
  const orders = await db.orders.findMany({
    where: { orgId, createdAt: { gte: from, lt: to } },
    orderBy: { createdAt: "asc" },
  });
  const lines = [["Order ID", "Date", "Customer", "PO Number", "Total", "Status"].join(";")];
  for (const o of orders) {
    lines.push(
      [
        o.id,
        o.createdAt.toISOString(),
        `"${o.customerName}"`,
        o.metadata?.poNumber ?? "",
        formatMoney(o.totalCents, o.currency),
        o.status,
      ].join(";"),
    );
  }
  return lines.join("\n");
}

// Globex: like Acme but no status column, and cancelled orders excluded
export async function exportOrdersCsvGlobex(orgId: string, from: Date, to: Date): Promise<string> {
  const orders = await db.orders.findMany({
    where: { orgId, createdAt: { gte: from, lt: to }, status: { not: "cancelled" } },
    orderBy: { createdAt: "asc" },
  });
  const lines = [["Order ID", "Date", "Customer", "PO Number", "Total"].join(";")];
  for (const o of orders) {
    lines.push(
      [
        o.id,
        o.createdAt.toISOString(),
        `"${o.customerName}"`,
        o.metadata?.poNumber ?? "",
        formatMoney(o.totalCents, o.currency),
      ].join(";"),
    );
  }
  return lines.join("\n");
}

// Finance opens these in Excel, which chokes on the time part.
export function fixDatesForExcel(csv: string): string {
  return csv.replace(/T\d{2}:\d{2}:\d{2}\.\d{3}Z/g, "");
}

// Customer names containing quotes were breaking rows (support ticket #4412).
export function fixEmbeddedQuotes(csv: string): string {
  return csv.replace(/([^,;\n])"([^,;\n])/g, '$1""$2');
}

export async function handleExportRequest(req: ExportRequest): Promise<string> {
  let csv: string;
  if (req.orgId === ACME_ORG_ID) {
    csv = await exportOrdersCsvAcme(req.orgId, req.from, req.to);
  } else if (req.orgId === GLOBEX_ORG_ID) {
    csv = await exportOrdersCsvGlobex(req.orgId, req.from, req.to);
  } else {
    csv = await exportOrdersCsv(req.orgId, req.from, req.to);
  }
  if (req.forExcel) {
    csv = fixDatesForExcel(csv);
  }
  csv = fixEmbeddedQuotes(csv);
  // TODO: refunds export has its own copy of the above, keep them in sync
  return csv;
}
```

Sales already has two more enterprise customers asking for "their" format next quarter.
