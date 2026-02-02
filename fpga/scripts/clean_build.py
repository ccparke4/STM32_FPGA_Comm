import os
import shutil
import glob

# Configuration
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) # fpga/
DIRS_TO_REMOVE = [
    "build_synth",
    "reports",
    ".Xil",
    "xsim.dir"
]

FILES_TO_REMOVE = [
    "vivado*.log",
    "vivado*.jou",
    "xsim*.log",
    "xsim*.jou",
    "usage_statistics_webtalk.xml",
    "usage_statistics_webtalk.html"
]

def clean():
    print(f"[CLEAN] Cleaning project root: {PROJECT_ROOT}")
    
    # 1. Remove Directories
    for d in DIRS_TO_REMOVE:
        path = os.path.join(PROJECT_ROOT, d)
        if os.path.exists(path):
            print(f"  - Removing Directory: {d}")
            try:
                shutil.rmtree(path)
            except Exception as e:
                print(f"    [ERROR] Could not remove {d}: {e}")

    # 2. Remove Files (Glob patterns)
    for pattern in FILES_TO_REMOVE:
        search_path = os.path.join(PROJECT_ROOT, pattern)
        files = glob.glob(search_path)
        for f in files:
            print(f"  - Removing File: {os.path.basename(f)}")
            try:
                os.remove(f)
            except Exception as e:
                print(f"    [ERROR] Could not remove {f}: {e}")

    print("[CLEAN] Done.")

if __name__ == "__main__":
    clean()