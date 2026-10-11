import os
import shutil
import datetime
import sys
import argparse
from PIL import Image

ASSETS_DIR = "assets"
BACKUP_DIR = "assets_backup"
VALID_EXTENSIONS = (".png", ".PNG", ".webp", ".WEBP", ".jpg", ".jpeg", ".JPG")

# TABELA REVISADA COM NOVAS NOMENCLATURAS E MEDIDAS DOBRADAS (2X SUPERSAMPLING)
RULES_2X = [
    ("char_full_alien_endless", 400, 1200, "fit"),
    ("char_port_", 240, 240, "fit"),
    ("char_closed_", 240, 240, "fit"),
    ("char_damaged_", 240, 240, "fit"),
    ("char_full_", 700, 1200, "fit"),
    ("enemy_boss_", 700, 700, "fit"),
    ("enemy_", 640, 640, "fit"),
    ("cutscene_", 1920, 1080, "fit"),
    ("ui_title_logo", 1284, 200, "fit"),
    ("ui_title_illustration", 1920, 1080, "fit"),
    ("ui_gameover_illustration", 1920, 1080, "fit"),
    ("ui_tutorial", 1920, 1080, "fit"),
    ("ui_item_detector", 512, 512, "fit"),
    ("prop_chest_", 512, 512, "fit"),
    ("prop_portal", 512, 800, "fit"),
    ("prop_heal_pod", 512, 900, "fit"),
    ("prop_csouter_", 512, 900, "fit"),
    ("prop_spooter_", 512, 900, "fit"),
    ("prop_terminal_", 512, 900, "fit"),
    ("env_wall_", 1024, 1024, "fit"),
    ("env_floor_", 1024, 1024, "fit"),
    ("env_ceiling_", 1024, 1024, "fit"),
]

def clean_stepped_downscale(img: Image.Image, target_w: int, target_h: int, mode: str = "fit") -> Image.Image:
    cur_w, cur_h = img.size
    if mode == "fit":
        ratio = min(target_w / cur_w, target_h / cur_h)
        if ratio >= 1.0: return img
        final_w = max(1, int(cur_w * ratio))
        final_h = max(1, int(cur_h * ratio))
    else:
        final_w, final_h = target_w, target_h

    temp_w, temp_h = cur_w, cur_h
    working_img = img
    while temp_w > final_w * 2 and temp_h > final_h * 2:
        temp_w = int(temp_w * 0.5)
        temp_h = int(temp_h * 0.5)
        working_img = working_img.resize((temp_w, temp_h), Image.Resampling.LANCZOS)

    return working_img.resize((final_w, final_h), Image.Resampling.LANCZOS)

def safe_backup_existing(dest_path: str, filename: str):
    """Se o arquivo já existe no destino (assets/), faz um backup preventivo no archive antes de sobrescrever."""
    if os.path.exists(dest_path):
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        archive_dir = os.path.join(BACKUP_DIR, "archive", timestamp)
        os.makedirs(archive_dir, exist_ok=True)
        
        backup_file_path = os.path.join(archive_dir, filename)
        shutil.copy2(dest_path, backup_file_path)
        print(f"   🛡️ Backup preventivo criado em: {archive_dir}/{filename}")

def process_single_file(filename: str, source_dir: str) -> bool:
    filename = os.path.basename(filename)
    
    if not filename.endswith(VALID_EXTENSIONS):
        found = False
        for ext in VALID_EXTENSIONS:
            possible_file = filename + ext
            if os.path.exists(os.path.join(source_dir, possible_file)):
                filename = possible_file
                found = True
                break
        if not found:
            print(f"❌ Arquivo '{filename}' não encontrado em '{source_dir}'")
            return False

    src_path = os.path.join(source_dir, filename)
    dest_path = os.path.join(ASSETS_DIR, filename)

    if not os.path.exists(src_path):
        print(f"❌ Arquivo não encontrado em '{source_dir}': {filename}")
        return False

    base_name = os.path.splitext(filename)[0]
    matched_rule = None
    for rule in RULES_2X:
        prefix, target_w, target_h, fit_mode = rule
        if base_name.startswith(prefix) or base_name == prefix:
            matched_rule = rule
            break

    if not matched_rule:
        print(f"⚠️ Nenhuma regra encontrada para: {filename}")
        return False

    _, target_w, target_h, fit_mode = matched_rule

    try:
        # Garante o backup preventivo caso já exista uma versão no projeto
        safe_backup_existing(dest_path, filename)

        with Image.open(src_path) as img:
            img_rgba = img.convert("RGBA")
            orig_size = img_rgba.size
            opt_img = clean_stepped_downscale(img_rgba, target_w, target_h, fit_mode)
            opt_img.save(dest_path, "PNG", optimize=True)
            print(f"✨ [2X NÍTIDO] {filename:<32} {orig_size[0]}x{orig_size[1]} -> {opt_img.size[0]}x{opt_img.size[1]}")

            import_file = dest_path + ".import"
            if os.path.exists(import_file):
                os.remove(import_file)
            return True
    except Exception as e:
        print(f"❌ Erro ao processar {filename}: {e}")
        return False

def run_asset_cleaner_2x(target_files: list = None):
    if not os.path.exists(ASSETS_DIR):
        os.makedirs(ASSETS_DIR, exist_ok=True)

    if not os.path.exists(BACKUP_DIR):
        print(f"❌ Pasta '{BACKUP_DIR}' não encontrada.")
        return

    print(f"📦 Puxando imagens originais de: '{BACKUP_DIR}'")

    if target_files:
        processed = 0
        for target_file in target_files:
            if process_single_file(target_file, BACKUP_DIR):
                processed += 1
        print(f"\n🎉 {processed} arquivo(s) processado(s) com sucesso!")
    else:
        processed = 0
        all_files = [f for f in os.listdir(BACKUP_DIR) if os.path.isfile(os.path.join(BACKUP_DIR, f))]
        for filename in all_files:
            if process_single_file(filename, BACKUP_DIR):
                processed += 1
        print(f"\n🎉 Concluído! {processed} arquivos processados na resolução 2x.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Redimensiona assets para resolução 2x com backup preventivo.")
    parser.add_argument("files", nargs="*", help="Nome(s) ou caminho(s) do(s) arquivo(s) específico(s) (opcional)")
    args = parser.parse_args()

    run_asset_cleaner_2x(args.files)
