#!/usr/bin/env node
/**
 * Validate a baked QR tree schematic decodes to the expected URL.
 * Reads .json metadata and verifies .mts node grid matches the QR matrix.
 *
 * Usage: node validate-qr-tree.mjs --id aarontolentino
 */

import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { inflateSync } from "node:zlib";
import QRCode from "qrcode";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCHEM_DIR = join(__dirname, "../mods/hashimon_qr_tree/schematics");

function parseArgs(argv) {
  let id = null;
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === "--id") id = argv[i + 1];
    i++;
  }
  if (!id) {
    console.error("Required: --id");
    process.exit(1);
  }
  return { id };
}

function moduleIsDark(modules, moduleX, moduleZ, quietZone) {
  const qrX = moduleX - quietZone;
  const qrZ = moduleZ - quietZone;
  if (qrX < 0 || qrZ < 0 || qrX >= modules.size || qrZ >= modules.size) {
    return false;
  }
  return !!modules.get(qrZ, qrX);
}

function readMtsNodeGrid(mtsPath, meta) {
  const buf = readFileSync(mtsPath);
  let off = 0;
  const sig = buf.readUInt32BE(off);
  off += 4;
  if (sig !== 0x4d54534d) {
    throw new Error("Invalid MTS signature");
  }
  const version = buf.readUInt16BE(off);
  off += 2;
  if (version !== 4) {
    throw new Error("Unsupported MTS version: " + version);
  }
  const sizeX = buf.readUInt16BE(off);
  off += 2;
  const sizeY = buf.readUInt16BE(off);
  off += 2;
  const sizeZ = buf.readUInt16BE(off);
  off += 2;

  if (sizeX !== meta.size_x || sizeY !== meta.size_y || sizeZ !== meta.size_z) {
    throw new Error(`Size mismatch json vs mts: ${sizeX}x${sizeY}x${sizeZ}`);
  }

  off += sizeY; // slice probs
  const nameCount = buf.readUInt16BE(off);
  off += 2;
  const names = [];
  for (let n = 0; n < nameCount; n++) {
    const len = buf.readUInt16BE(off);
    off += 2;
    names.push(buf.toString("utf8", off, off + len));
    off += len;
  }

  const inflated = inflateSync(buf.subarray(off));
  const nodeCount = sizeX * sizeY * sizeZ;
  const darkIdx = names.indexOf("hashimon_qr_tree:dark");
  const lightIdx = names.indexOf("hashimon_qr_tree:light");
  if (darkIdx < 0 || lightIdx < 0) {
    throw new Error("Schematic missing hashimon_qr nodes: " + names.join(", "));
  }

  const darkAt = new Array(sizeX * sizeZ).fill(false);
  let i = 0;
  for (let z = 0; z < sizeZ; z++) {
    for (let y = 0; y < sizeY; y++) {
      for (let x = 0; x < sizeX; x++) {
        const content = inflated.readUInt16BE(i * 2);
        if (y === 0) {
          darkAt[z * sizeX + x] = content === darkIdx;
        }
        i++;
      }
    }
  }
  return { darkAt, sizeX, sizeZ, darkIdx, lightIdx, nodeCount };
}

function main() {
  const { id } = parseArgs(process.argv);
  const jsonPath = join(SCHEM_DIR, `sponsor_${id}.json`);
  const mtsPath = join(SCHEM_DIR, `sponsor_${id}.mts`);

  if (!existsSync(jsonPath) || !existsSync(mtsPath)) {
    console.error("Missing baked files for id:", id);
    console.error("Run: node bake-qr-tree.mjs --id", id, '--url "..."');
    process.exit(1);
  }

  const meta = JSON.parse(readFileSync(jsonPath, "utf8"));
  const expected = QRCode.create(meta.url, { errorCorrectionLevel: "H" }).modules;
  const { darkAt, sizeX, sizeZ } = readMtsNodeGrid(mtsPath, meta);
  const { module_size: moduleSize, quiet_zone: quietZone, grid_modules: gridModules } = meta;

  let mismatches = 0;
  for (let mz = 0; mz < gridModules; mz++) {
    for (let mx = 0; mx < gridModules; mx++) {
      const expectedDark = moduleIsDark(expected, mx, mz, quietZone);
      const sx = mx * moduleSize;
      const sz = mz * moduleSize;
      const cx = sx + Math.floor(moduleSize / 2);
      const cz = sz + Math.floor(moduleSize / 2);
      const actualDark = darkAt[cz * sizeX + cx];
      if (actualDark !== expectedDark) {
        mismatches++;
      }
    }
  }

  if (mismatches > 0) {
    console.error(`FAIL: ${mismatches} module(s) mismatch between MTS and URL QR`);
    process.exit(1);
  }

  console.log(`OK: sponsor_${id} MTS matches URL QR matrix`);
  console.log(`  URL: ${meta.url}`);
  console.log(`  Footprint: ${meta.footprint}x${meta.footprint} nodes`);
  console.log(`  QR modules: ${meta.qr_modules}x${meta.qr_modules} (ECC ${meta.ecc})`);
}

main();
