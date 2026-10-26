import { readFileSync } from 'node:fs';

export type IntegrityVerdict = 'pass' | 'fail' | 'unevaluated';

export interface IntegrityProvider {
  readonly name: string;
  verify(token: string | undefined, packageName: string): Promise<IntegrityVerdict>;
}

/** Without Play Integrity credentials every verdict is "unevaluated" (flag play_integrity_enforced stays off). */
export class MockIntegrityProvider implements IntegrityProvider {
  readonly name = 'mock';
  async verify(token: string | undefined): Promise<IntegrityVerdict> {
    if (token === 'test-fail') return 'fail';
    if (token === 'test-pass') return 'pass';
    return 'unevaluated';
  }
}

/** Google Play Integrity: decodes the token server-side and requires a recognised app on a genuine device. */
export class PlayIntegrityProvider implements IntegrityProvider {
  readonly name = 'play';
  constructor(private serviceAccountFile: string) {}
  async verify(token: string | undefined, packageName: string): Promise<IntegrityVerdict> {
    if (!token) return 'fail';
    const { GoogleAuth } = await import('google-auth-library');
    const auth = new GoogleAuth({
      credentials: JSON.parse(readFileSync(this.serviceAccountFile, 'utf8')),
      scopes: ['https://www.googleapis.com/auth/playintegrity'],
    });
    const client = await auth.getClient();
    const res: any = await client.request({
      url: `https://playintegrity.googleapis.com/v1/${packageName}:decodeIntegrityToken`,
      method: 'POST',
      data: { integrity_token: token },
    });
    const p = res.data?.tokenPayloadExternal;
    const appOk = p?.appIntegrity?.appRecognitionVerdict === 'PLAY_RECOGNIZED';
    const deviceOk = (p?.deviceIntegrity?.deviceRecognitionVerdict ?? []).includes('MEETS_DEVICE_INTEGRITY');
    return appOk && deviceOk ? 'pass' : 'fail';
  }
}
