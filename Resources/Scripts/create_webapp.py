#!/usr/bin/env python3

import argparse
import importlib.util
import sys
from pathlib import Path


WEBAPP_MANAGER_COMMON = Path("/usr/lib/webapp-manager/common.py")

# Stesse categorie mostrate dalla UI di Web App Manager
UI_CATEGORIES = [
    ("WebApps", "Web"),
    ("Network", "Internet"),
    ("Utility", "Accessories"),
    ("Game", "Games"),
    ("Graphics", "Graphics"),
    ("Office", "Office"),
    ("AudioVideo", "Sound & Video"),
    ("Development", "Programming"),
    ("Education", "Education"),
]


def load_webapp_manager_module():
    if not WEBAPP_MANAGER_COMMON.exists():
        raise FileNotFoundError(
            f"File non trovato: {WEBAPP_MANAGER_COMMON}\n"
            "Assicurati che webapp-manager sia installato."
        )

    spec = importlib.util.spec_from_file_location(
        "webapp_manager_common",
        str(WEBAPP_MANAGER_COMMON),
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Impossibile caricare common.py di webapp-manager.")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def browser_exists(test_path: str) -> bool:
    return Path(test_path).expanduser().exists()


def inject_extra_browsers(module, browsers):
    """
    Fallback utile se la versione locale di Web App Manager non include ancora
    Vivaldi nel proprio get_supported_browsers().
    """
    existing_names = {b.name for b in browsers}
    Browser = module.Browser
    CHROMIUM = module.BROWSER_TYPE_CHROMIUM

    extra = []

    if "Vivaldi" not in existing_names:
        extra.append(
            Browser(CHROMIUM, "Vivaldi", "vivaldi-stable", "/usr/bin/vivaldi-stable")
        )

    if "Vivaldi (Alt)" not in existing_names:
        extra.append(
            Browser(CHROMIUM, "Vivaldi (Alt)", "vivaldi", "/usr/bin/vivaldi")
        )

    return browsers + extra


def get_all_browsers(module):
    browsers = module.WebAppManager.get_supported_browsers()
    return inject_extra_browsers(module, browsers)


def get_installed_browsers(module):
    return [b for b in get_all_browsers(module) if browser_exists(b.test_path)]


def normalize_text(value: str) -> str:
    return value.strip().casefold()


def resolve_category(user_value: str) -> str:
    if not user_value:
        return "WebApps"

    needle = normalize_text(user_value)

    for category_id, category_name in UI_CATEGORIES:
        if normalize_text(category_id) == needle:
            return category_id
        if normalize_text(category_name) == needle:
            return category_id

    valid = ", ".join(f"{cid} ({cname})" for cid, cname in UI_CATEGORIES)
    raise RuntimeError(
        f"Categoria non valida: {user_value}\n"
        f"Categorie disponibili: {valid}"
    )


def list_categories():
    print("Categorie disponibili:")
    for category_id, category_name in UI_CATEGORIES:
        print(f" - {category_id} ({category_name})")


def pick_browser(installed_browsers, requested_name=None):
    if not installed_browsers:
        raise RuntimeError(
            "Nessun browser supportato da Web App Manager risulta installato."
        )

    if requested_name:
        requested = normalize_text(requested_name)

        # Match esatto sul nome mostrato
        for browser in installed_browsers:
            if normalize_text(browser.name) == requested:
                return browser

        # Alias comuni per Vivaldi
        if requested in {"vivaldi", "vivaldi-stable"}:
            for preferred in ("Vivaldi", "Vivaldi (Alt)"):
                for browser in installed_browsers:
                    if browser.name == preferred:
                        return browser

        # Match permissivo
        for browser in installed_browsers:
            if requested in normalize_text(browser.name):
                return browser

        available = ", ".join(b.name for b in installed_browsers)
        raise RuntimeError(
            f"Browser richiesto non trovato: {requested_name}\n"
            f"Browser disponibili: {available}"
        )

    # Default: preferisci Vivaldi
    preferred_order = [
        "Vivaldi",
        "Vivaldi (Alt)",
        "Vivaldi Snapshot",
        "Vivaldi (Flatpak)",
        "Chromium",
        "Ungoogled Chromium",
        "Chrome",
        "Brave",
        "Brave Browser",
        "Brave (Bin)",
        "Firefox",
        "LibreWolf",
        "Zen (Flatpak)",
        "Epiphany",
        "Falkon",
    ]

    for preferred in preferred_order:
        for browser in installed_browsers:
            if browser.name == preferred:
                return browser

    return installed_browsers[0]


def list_browsers(installed_browsers, all_browsers):
    print("Browser supportati da Web App Manager:")
    for browser in all_browsers:
        status = "installato" if any(
            browser.name == b.name and browser.test_path == b.test_path
            for b in installed_browsers
        ) else "non installato"
        print(f" - {browser.name} [{status}] ({browser.test_path})")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Crea una Web App usando il backend di Linux Mint Web App Manager."
    )

    parser.add_argument("--name", help="Nome della web app")
    parser.add_argument("--url", help="URL della web app")
    parser.add_argument(
        "--desc",
        default="Web App",
        help="Descrizione della web app",
    )
    parser.add_argument(
        "--icon",
        default="web-browser",
        help=(
            "Icona della web app. Può essere un nome icona del tema o un path a un file."
        ),
    )
    parser.add_argument(
        "--category",
        default="WebApps",
        help=(
            "Categoria della web app. Puoi usare l'ID tecnico o il nome UI, "
            'es: "Network" oppure "Internet". Default: WebApps'
        ),
    )
    parser.add_argument(
        "--browser",
        default="Vivaldi",
        help='Browser da usare, es. "Vivaldi", "Firefox", "Chromium". Default: Vivaldi',
    )
    parser.add_argument(
        "--custom-parameters",
        default="",
        help="Parametri aggiuntivi da passare al browser",
    )
    parser.add_argument(
        "--navbar",
        action="store_true",
        help="Abilita navbar quando supportata",
    )
    parser.add_argument(
        "--private-window",
        action="store_true",
        help="Apre la web app in finestra privata quando supportato",
    )
    parser.add_argument(
        "--no-isolate",
        action="store_true",
        help="Disabilita il profilo isolato",
    )
    parser.add_argument(
        "--list-browsers",
        action="store_true",
        help="Mostra i browser supportati e rilevati, poi esce",
    )
    parser.add_argument(
        "--list-categories",
        action="store_true",
        help="Mostra le categorie disponibili, poi esce",
    )

    return parser.parse_args()


def main():
    args = parse_args()

    try:
        module = load_webapp_manager_module()
        manager = module.WebAppManager()

        all_browsers = get_all_browsers(module)
        installed_browsers = get_installed_browsers(module)

        if args.list_categories:
            list_categories()
            return 0

        if args.list_browsers:
            list_browsers(installed_browsers, all_browsers)
            return 0

        if not args.name or not args.url:
            print("Errore: --name e --url sono obbligatori.", file=sys.stderr)
            return 2

        category_id = resolve_category(args.category)
        browser = pick_browser(installed_browsers, args.browser)

        # Epiphany vuole un file icona reale
        if browser.name == "Epiphany":
            icon_path = Path(args.icon).expanduser()
            if not icon_path.is_file():
                raise RuntimeError(
                    "Con Epiphany l'icona deve essere un file esistente (es. PNG/SVG)."
                )

        icon_value = str(Path(args.icon).expanduser()) \
            if Path(args.icon).expanduser().exists() \
            else args.icon

        manager.create_webapp(
            name=args.name,
            desc=args.desc,
            url=args.url,
            icon=icon_value,
            category=category_id,
            browser=browser,
            custom_parameters=args.custom_parameters,
            isolate_profile=not args.no_isolate,
            navbar=args.navbar,
            privatewindow=args.private_window,
        )

        print(f'Web app creata con successo: "{args.name}"')
        print(f"Browser usato: {browser.name}")
        print(f"Categoria usata: {category_id}")
        return 0

    except Exception as exc:
        print(f"Errore: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
