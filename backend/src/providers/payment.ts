import { randomInt } from 'node:crypto';

export type PaymentMethod = 'cashplus' | 'wafacash' | 'card' | 'wallet';

export interface PaymentRequest {
  subscriptionId: string;
  driverId: string;
  amount: number;
  method: PaymentMethod;
}

export interface PaymentInstructions {
  provider_ref: string;
  instructions: Record<string, unknown>;
}

/**
 * Subscription payments (D14). The platform never holds money: cash codes are paid at agents
 * and settled by the provider directly to the company account; card/wallet go through the provider's hosted page.
 * Without merchant keys every adapter runs in mock mode and an admin marks payments as received.
 */
export interface PaymentProvider {
  readonly method: PaymentMethod;
  readonly mock: boolean;
  create(req: PaymentRequest): Promise<PaymentInstructions>;
}

class MockCashCodeProvider implements PaymentProvider {
  readonly mock = true;
  constructor(readonly method: 'cashplus' | 'wafacash') {}
  async create(req: PaymentRequest): Promise<PaymentInstructions> {
    const code = String(randomInt(10 ** 9, 10 ** 10));
    return {
      provider_ref: `${this.method.toUpperCase()}-${code}`,
      instructions: { kind: 'cash_code', agent: this.method === 'cashplus' ? 'CashPlus' : 'Wafacash', code, amount: req.amount, valid_hours: 72 },
    };
  }
}

class MockHostedProvider implements PaymentProvider {
  readonly mock = true;
  constructor(readonly method: 'card' | 'wallet', private baseUrl: string) {}
  async create(req: PaymentRequest): Promise<PaymentInstructions> {
    const ref = `${this.method.toUpperCase()}-${req.subscriptionId.slice(0, 8)}`;
    return {
      provider_ref: ref,
      instructions: { kind: 'hosted_page', url: `${this.baseUrl}/pay/unavailable?ref=${ref}`, amount: req.amount, note: 'Online payment is not connected yet; pay with a cash code.' },
    };
  }
}

export function createPaymentProviders(baseUrl: string): Record<PaymentMethod, PaymentProvider> {
  return {
    cashplus: new MockCashCodeProvider('cashplus'),
    wafacash: new MockCashCodeProvider('wafacash'),
    card: new MockHostedProvider('card', baseUrl),
    wallet: new MockHostedProvider('wallet', baseUrl),
  };
}
