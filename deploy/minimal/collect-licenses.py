from pathlib import Path
import json
import shutil

output = Path("/licenses")
output.mkdir()
shutil.copy2("/src/LICENSE", output / "RUSTFS-LICENSE")
for name in ["LICENSE", "COPYING"]:
    shutil.copy2(Path("/tmp/upx-src") / name, output / ("UPX-" + name))
packages = []
sources = sorted(Path("/usr/local/cargo/registry/src").glob("*/*"))
sources += sorted(Path("/usr/local/cargo/git/checkouts").glob("*/*"))
for source in sources:
    name = source.name if source.parent.parent.name == "src" else source.parent.name + "-" + source.name
    destination = output / "third-party" / name
    notices = [p for p in source.rglob("*") if p.is_file() and p.name.upper().startswith(("LICENSE", "LICENCE", "COPYING", "NOTICE"))]
    if notices:
        destination.mkdir(parents=True)
        for notice in notices:
            target = destination / notice.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(notice, target)
    packages.append(name)
    # MPL-2.0 source accompanies this unmodified dependency.
    if source.name == "option-ext-0.2.0":
        shutil.make_archive(str(output / source.name), "gztar", source)
(output / "included-sources.json").write_text(json.dumps(packages, indent=2) + "\n")
