import { describe, expect, it } from "vitest"
import { createMockPaymentProvider } from "./payments"

describe("mock payments", () => {
  it("returns a receipt without charging", async () => {
    const payments = createMockPaymentProvider({ delayMs: 0 })
    const result = await payments.purchase("cores_small")
    expect(result.ok).toBe(true)
    if (result.ok) expect(result.transactionId).toContain("cores_small")
    expect(payments.mode).toBe("mock")
  })

  it("can cancel or fail on purpose", async () => {
    const payments = createMockPaymentProvider({ delayMs: 0 })
    const cancelled = await payments.purchase("cores_small", { outcome: "cancel" })
    const failed = await payments.purchase("cores_small", { outcome: "fail" })
    expect(cancelled.ok).toBe(false)
    expect(failed.ok).toBe(false)
  })
})
