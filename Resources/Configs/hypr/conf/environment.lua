local env = {
    -- NVIDIA https://wiki.hyprland.org/Nvidia/
    { "GBM_BACKEND", "nvidia-drm" },
    { "LIBVA_DRIVER_NAME", "nvidia" },
    { "SDL_VIDEODRIVER", "wayland" },
    { "WLR_DRM_NO_ATOMIC", "1" },
    { "__GLX_VENDOR_LIBRARY_NAME", "nvidia" },
    { "__NV_PRIME_RENDER_OFFLOAD", "1" },
    { "__VK_LAYER_NV_optimus", "NVIDIA_only" },

    -- VM / NVIDIA fallbacks
    { "WLR_NO_HARDWARE_CURSORS", "1" },
    { "WLR_RENDERER_ALLOW_SOFTWARE", "1" },

    -- Dolphin fix
    { "XDG_MENU_PREFIX", "arch-" },

    -- xdg-desktop-portal
    { "XDG_CURRENT_DESKTOP", "Hyprland" },
    { "XDG_SESSION_TYPE", "wayland" },
    { "XDG_SESSION_DESKTOP", "Hyprland" },

    -- Theme
    { "GTK_THEME", "Adwaita:dark" },
    { "GTK_APPLICATION_PREFER_DARK_THEME", "1" },
    { "QT_QPA_PLATFORMTHEME", "qt6ct" },
    { "QT_QPA_PLATFORM", "wayland" },

    -- Electron / Chromium
    { "ELECTRON_OZONE_PLATFORM_HINT", "auto" },
    { "ELECTRON_FORCE_DARK_MODE", "1" },
    { "CHROME_FORCE_DARK_MODE", "1" },
}

for _, item in ipairs(env) do
    hl.env(item[1], item[2])
end

hl.exec_cmd("XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental")
