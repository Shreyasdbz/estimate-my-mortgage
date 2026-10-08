// Rasterize the original vector without adding masks, glass, shadows, or third-party runtime dependencies to the app.
// Usage: node render-icons.cjs /absolute/path/to/sharp
const fs = require('node:fs/promises');
const path = require('node:path');
if (process.argv.length !== 3) {
  console.error('Usage: node render-icons.cjs /absolute/path/to/sharp');
  process.exit(2);
}
const sharp = require(process.argv[2]);
const sourcePath = path.join(__dirname, 'mortgage-icon.svg');
const outputPath = path.resolve(__dirname, '../../EstimateMyMortgage/Assets.xcassets/AppIconModern.appiconset');

// Exact source markers keep variant changes explicit. Stop before writing files if an edited SVG no longer matches the palette contract.
function replaceRequired(source, marker, replacement) {
  const first = source.indexOf(marker);
  if (first < 0 || source.indexOf(marker, first + marker.length) >= 0) {
    throw new Error('The vector source changed. Update the variant palette markers before regenerating icons.');
  }
  return source.replace(marker, replacement);
}

async function renderIcons() {
  const source = await fs.readFile(sourcePath, 'utf8');
  const variants = [
    ['AppIcon-Default.png', source, false],
    ['AppIcon-Dark.png', replaceRequired(replaceRequired(source, '<rect id="background" width="1024" height="1024" fill="#5856D6"/>', ''), 'id="house" mask="url(#calculation)" fill="#FFFFFF"', 'id="house" mask="url(#calculation)" fill="#B5B3FF"'), true],
    ['AppIcon-Tinted.png', replaceRequired(source, 'id="background" width="1024" height="1024" fill="#5856D6"', 'id="background" width="1024" height="1024" fill="#000000"'), false]
  ];
  await fs.mkdir(outputPath, { recursive: true });
  for (const [filename, svg, alpha] of variants) {
    let image = sharp(Buffer.from(svg)).resize(1024, 1024);
    if (!alpha) image = image.removeAlpha();
    await image.png().toFile(path.join(outputPath, filename));
  }
}
renderIcons().catch(error => { console.error(error); process.exitCode = 1; });
