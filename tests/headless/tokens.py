"""Token values as compiled: token_values(repo, sassc, names) -> {name: "3px"}."""
import re
import subprocess


def token_values(repo, sassc, names):
    scss = "@import 'tokens';\n.t {\n" + "".join(f"  --{n}: #{{$radius-{n}}};\n" for n in names) + "}\n"
    out = subprocess.run([sassc, "-I", f"{repo}/src", "-s"], input=scss,
                         capture_output=True, text=True, check=True).stdout
    return dict(re.findall(r"--([\w-]+):\s*([^;]+);", out))
