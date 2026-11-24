import { productById } from "../content/products"

export type PaymentOutcome = "success" | "cancel" | "fail"

export type PaymentResult =
  | { ok: true; productId: string; transactionId: string }
  | { ok: false; code: "cancelled" | "failed" | "unknown_product"; message: string }

/**
 * The game talks to this interface only. The mock waits and returns a receipt
 * id. A future RevenueCat adapter should satisfy the same shape.
 */
export interface PaymentProvider {
  readonly mode: "mock" | "revenuecat"
  purchase(productId: string, options?: { outcome?: PaymentOutcome }): Promise<PaymentResult>
  restore(): Promise<{ ok: true }>
}

export function createMockPaymentProvider(options?: { delayMs?: number }): PaymentProvider {
  const delayMs = options?.delayMs ?? 700
  let sequence = 0
  return {
    mode: "mock",
    async purchase(productId, purchaseOptions) {
      if (delayMs > 0) await wait(delayMs)
      if (!productById(productId)) {
        return { ok: false, code: "unknown_product", message: "That product is not in the test catalog." }
      }
      const outcome = purchaseOptions?.outcome ?? "success"
      if (outcome === "cancel") {
        return { ok: false, code: "cancelled", message: "Test purchase cancelled." }
      }
      if (outcome === "fail") {
        return { ok: false, code: "failed", message: "The test charge didn't go through. Nothing was added." }
      }
      sequence += 1
      return { ok: true, productId, transactionId: `mock_${productId}_${sequence}` }
    },
    async restore() {
      if (delayMs > 0) await wait(Math.min(delayMs, 400))
      return { ok: true }
    },
  }
}

export function createPaymentProvider(): PaymentProvider {
  const mode = import.meta.env.VITE_IAP ?? "mock"
  if (mode !== "mock") {
    throw new Error(
      `IAP mode "${mode}" is not bundled. Keep VITE_IAP=mock until a RevenueCat provider is added. See the README.`,
    )
  }
  return createMockPaymentProvider()
}

let singleton: PaymentProvider | null = null

export function getPaymentProvider(): PaymentProvider {
  singleton ??= createPaymentProvider()
  return singleton
}

function wait(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms)
  })
}
