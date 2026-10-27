import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { DeleteObjectCommand, GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';

/** Private blob storage. Everything stored here is already encrypted by the caller. */
export interface StorageProvider {
  readonly name: string;
  put(key: string, data: Buffer): Promise<void>;
  get(key: string): Promise<Buffer>;
  delete(key: string): Promise<void>;
}

export class LocalStorage implements StorageProvider {
  readonly name = 'local';
  private root: string;
  constructor(root: string) {
    this.root = resolve(root);
  }
  private path(key: string) {
    const p = resolve(join(this.root, key));
    if (!p.startsWith(this.root)) throw new Error('invalid storage key');
    return p;
  }
  async put(key: string, data: Buffer) {
    const p = this.path(key);
    await mkdir(dirname(p), { recursive: true });
    await writeFile(p, data, { mode: 0o600 });
  }
  async get(key: string) {
    return readFile(this.path(key));
  }
  async delete(key: string) {
    await rm(this.path(key), { force: true });
  }
}

export class S3Storage implements StorageProvider {
  readonly name = 's3';
  private s3: S3Client;
  constructor(private opts: { endpoint: string; region: string; bucket: string; accessKey: string; secretKey: string }) {
    this.s3 = new S3Client({
      endpoint: opts.endpoint || undefined,
      region: opts.region || 'auto',
      forcePathStyle: true,
      credentials: { accessKeyId: opts.accessKey, secretAccessKey: opts.secretKey },
    });
  }
  async put(key: string, data: Buffer) {
    await this.s3.send(new PutObjectCommand({ Bucket: this.opts.bucket, Key: key, Body: data, ContentType: 'application/octet-stream' }));
  }
  async get(key: string) {
    const r = await this.s3.send(new GetObjectCommand({ Bucket: this.opts.bucket, Key: key }));
    return Buffer.from(await r.Body!.transformToByteArray());
  }
  async delete(key: string) {
    await this.s3.send(new DeleteObjectCommand({ Bucket: this.opts.bucket, Key: key }));
  }
}
