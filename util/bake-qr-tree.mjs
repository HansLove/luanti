#!/usr/bin/env node
/**
 * Bake a sponsor URL into a Luanti .mts schematic + metadata JSON.
 *
 * Usage:
 *   node bake-qr-tree.mjs --id aarontolentino --url "https://aarontolentino.com/"
 *
 * Options:
 *   --id           Sponsor id (output: sponsor_<id>.mts / .json)
 *   --url          Payload URL encoded in the QR
 *   --module-size  Nodes per QR module (default: 1 — most compact; use 4 for QR Island)
 *   --quiet-zone   Quiet zone in modules (default: 4)
 *   --out-dir      Output directory (default: ../mods/hashimon_qr_tree/schematics)
 */

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { deflateSync } from "node:zlib";
import QRCode from "qrcode";

const __dirname = dirname(fileURLToPath(import.meta.url));

const NODE_DARK = "hashimon_qr_tree:dark";
const NODE_LIGHT = "hashimon_qr_tree:light";
const MTSCHEM_SIGNATURE = 0x4d54534d;
const MTSCHEM_VERSION = 4;
const SLICE_PROB_ALWAYS = 0x7f;
const NODE_PROB_ALWAYS_FORCE = 0x7f | 0x80;

function parseArgs(argv) {
  const args = {
    id: null,
    url: null,
    moduleSize: 1,
    quietZone: 4,
    outDir: join(__dirname, "../mods/hashimon_qr_tree/schematics"),
  };
  for (let i = 2; i < argv.length; i++) {
    const key = argv[i];
    const val = argv[i + 1];
    if (key === "--id") args.id = val;
    else if (key === "--url") args.url = val;
    else if (key === "--module-size") args.moduleSize = Number(val);
    else if (key === "--quiet-zone") args.quietZone = Number(val);
    else if (key === "--out-dir") args.outDir = val;
    i++;
  }
  if (!args.id || !args.url) {
    console.error("Required: --id and --url");
    process.exit(1);
  }
  return args;
}

function serializeString16(str) {
  const body = Buffer.from(str, "utf8");
  const out = Buffer.alloc(2 + body.length);
  out.writeUInt16BE(body.length, 0);
  body.copy(out, 2);
  return out;
}

function writeMts(sizeX, sizeY, sizeZ, nodeNames, nodeIndices, param1Values) {
  const nodeCount = sizeX * sizeY * sizeZ;

  const header = Buffer.alloc(12);
  header.writeUInt32BE(MTSCHEM_SIGNATURE, 0);
  header.writeUInt16BE(MTSCHEM_VERSION, 4);
  header.writeUInt16BE(sizeX, 6);
  header.writeUInt16BE(sizeY, 8);
  header.writeUInt16BE(sizeZ, 10);

  const sliceProbs = Buffer.alloc(sizeY);
  sliceProbs.fill(SLICE_PROB_ALWAYS);

  const nameCount = Buffer.alloc(2);
  nameCount.writeUInt16BE(nodeNames.length, 0);
  const nameParts = nodeNames.map(serializeString16);
  const nameTable = Buffer.concat([nameCount, ...nameParts]);

  const contentBuf = Buffer.alloc(nodeCount * 2);
  const param1Buf = Buffer.alloc(nodeCount);
  const param2Buf = Buffer.alloc(nodeCount);

  for (let i = 0; i < nodeCount; i++) {
    contentBuf.writeUInt16BE(nodeIndices[i], i * 2);
    param1Buf[i] = param1Values[i];
    param2Buf[i] = 0;
  }

  const uncompressed = Buffer.concat([contentBuf, param1Buf, param2Buf]);
  const compressed = deflateSync(uncompressed);

  return Buffer.concat([header, sliceProbs, nameTable, compressed]);
}

function createQrMatrix(url) {
  const qr = QRCode.create(url, { errorCorrectionLevel: "H" });
  return qr.modules;
}

function moduleIsDark(modules, moduleX, moduleZ, quietZone) {
  const qrX = moduleX - quietZone;
  const qrZ = moduleZ - quietZone;
  if (qrX < 0 || qrZ < 0 || qrX >= modules.size || qrZ >= modules.size) {
    return false;
  }
  return !!modules.get(qrZ, qrX);
}

function buildSchematic(modules, moduleSize, quietZone) {
  const gridModules = modules.size + quietZone * 2;
  const sizeX = gridModules * moduleSize;
  const sizeZ = gridModules * moduleSize;
  // Single flat layer — most reliable for phone scanning from above.
  const sizeY = 1;

  const nodeNames = [NODE_DARK, NODE_LIGHT];
  const darkIdx = 0;
  const lightIdx = 1;

  const nodeCount = sizeX * sizeY * sizeZ;
  const nodeIndices = new Array(nodeCount);
  const param1Values = new Array(nodeCount).fill(NODE_PROB_ALWAYS_FORCE);

  let i = 0;
  for (let z = 0; z < sizeZ; z++) {
    for (let y = 0; y < sizeY; y++) {
      for (let x = 0; x < sizeX; x++) {
        const moduleX = Math.floor(x / moduleSize);
        const moduleZ = Math.floor(z / moduleSize);
        const dark = moduleIsDark(modules, moduleX, moduleZ, quietZone);
        nodeIndices[i] = dark ? darkIdx : lightIdx;
        i++;
      }
    }
  }

  return { sizeX, sizeY, sizeZ, nodeNames, nodeIndices, param1Values, gridModules };
}

function verifyDecode(modules, url) {
  const qr2 = QRCode.create(url, { errorCorrectionLevel: "H" });
  if (qr2.modules.size !== modules.size) {
    throw new Error("QR size mismatch on verify");
  }
  for (let z = 0; z < modules.size; z++) {
    for (let x = 0; x < modules.size; x++) {
      if (modules.get(z, x) !== qr2.modules.get(z, x)) {
        throw new Error(`QR matrix mismatch at ${x},${z}`);
      }
    }
  }
}

function renderTopDownPngMatrix(modules, moduleSize, quietZone) {
  const gridModules = modules.size + quietZone * 2;
  const px = gridModules * moduleSize;
  const rows = [];
  for (let z = 0; z < px; z++) {
    let row = "";
    for (let x = 0; x < px; x++) {
      const moduleX = Math.floor(x / moduleSize);
      const moduleZ = Math.floor(z / moduleSize);
      row += moduleIsDark(modules, moduleX, moduleZ, quietZone) ? "#" : ".";
    }
    rows.push(row);
  }
  return { width: px, height: px, rows };
}

async function main() {
  const args = parseArgs(process.argv);
  mkdirSync(args.outDir, { recursive: true });

  const modules = createQrMatrix(args.url);
  verifyDecode(modules, args.url);

  const schem = buildSchematic(modules, args.moduleSize, args.quietZone);
  const mtsBuffer = writeMts(
    schem.sizeX,
    schem.sizeY,
    schem.sizeZ,
    schem.nodeNames,
    schem.nodeIndices,
    schem.param1Values,
  );

  const baseName = `sponsor_${args.id}`;
  const mtsPath = join(args.outDir, `${baseName}.mts`);
  const jsonPath = join(args.outDir, `${baseName}.json`);

  const centerOffset = Math.floor(schem.sizeX / 2);
  const meta = {
    id: args.id,
    url: args.url,
    module_size: args.moduleSize,
    quiet_zone: args.quietZone,
    qr_modules: modules.size,
    grid_modules: schem.gridModules,
    size_x: schem.sizeX,
    size_y: schem.sizeY,
    size_z: schem.sizeZ,
    footprint: schem.sizeX,
    center_offset: centerOffset,
    ecc: "H",
    nodes: schem.nodeNames,
    baked_at: new Date().toISOString(),
  };

  writeFileSync(mtsPath, mtsBuffer);
  writeFileSync(jsonPath, JSON.stringify(meta, null, 2) + "\n");

  const preview = renderTopDownPngMatrix(modules, args.moduleSize, args.quietZone);
  const previewPath = join(args.outDir, `${baseName}_topdown.txt`);
  writeFileSync(
    previewPath,
    `# Top-down preview (${preview.width}x${preview.height}) — #=dark .=light\n` +
      preview.rows.join("\n") +
      "\n",
  );

  console.log(`Wrote ${mtsPath} (${mtsBuffer.length} bytes)`);
  console.log(`Wrote ${jsonPath}`);
  console.log(`Wrote ${previewPath}`);
  console.log(
    `QR ${modules.size}x${modules.size} modules → footprint ${schem.sizeX}x${schem.sizeZ} nodes (${schem.sizeY} tall)`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
