from pathlib import Path
import shutil
root=Path(r"G:\IntegralTec Systems\ITS-Webv2.1")
p=root/'src/index.css';s=p.read_text(encoding="utf-8");s+='''
/* Meltdown keeps the complete portrait game visible within its own card. */
.portfolio-software-card--meltdown .portfolio-software-art{min-height:auto;grid-template-rows:1fr;position:relative;background:#060a12}
.portfolio-software-card--meltdown .portfolio-software-screenshot{aspect-ratio:9 / 16;width:min(100%,300px);height:auto;object-fit:contain;justify-self:center}
''';p.write_text(s,encoding="utf-8")
assets=root/'src/assets/portfolio/obesecat-meltdown';assets.mkdir(parents=True,exist_ok=True)
shutil.copy2(r'G:\ObeseCat Meltdown\captures\phase_outfit.png',assets/'gameplay.png')
target=root/'public/games/obesecat-meltdown';shutil.copytree(r'G:\ObeseCat Meltdown\builds\web',target,dirs_exist_ok=True)
print('Portfolio entry, screenshot, and browser game installed.')
