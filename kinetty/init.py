import sys
from functools import partial

import kinetty
import effects
from kinetty.terminal import MenuMap
from kinetty import actions, keymap, particles, plugins
from kinetty.plugins import Plugin
from kinetty.terminal import CursorTrailDecay, CursorTrailThreshold, SymbolMap, TextComposition

# Repository plugin modules become importable; setup does not replace the current world.
plugin_spec = [
    # Development checkout of kinetty/snow.kinetty.
    Plugin(dir="/Users/kiyoon/project/wezterm-gureum/snow.kinetty"),
    Plugin(dir="/Users/kiyoon/project/wezterm-gureum/worlds.kinetty"),
    Plugin(dir="/Users/kiyoon/project/wezterm-gureum/volleyball.kinetty"),
    Plugin(dir="/Users/kiyoon/project/wezterm-gureum/silksong.kinetty"),
    Plugin(dir="/Users/kiyoon/project/wezterm-gureum/edinburgh-castle.kinetty"),
]
plugins.setup(spec=plugin_spec)

import snow
snow.setup(enabled=False, opacity=1.0, intensity=1.6)


follow = effects.Behavior(
    idle=effects.Frame(
        camera=effects.Camera(zoom=2.0, drift_px=20, drift_speed=2, shake_px=0, cursor_response=effects.CameraCursorResponse(tilt_limit_deg=18)),
        sheet=effects.Sheet(shape='saddle', ripple=1, shapes=effects.SheetShapes(saddle=effects.SheetShapesSaddle(curvature_deg=5))),
        typing=effects.Typing(sheet_splash=effects.TypingSheetSplash(scale=2.5), particles='sparks', combo=True),
    )
)
exaggerated = effects.Behavior(
    idle=effects.Frame(sheet=effects.Sheet(ripple=0.25)),
    typing=effects.Frame(
        camera=effects.Camera(zoom=2.0, drift_px=20, drift_speed=2, shake_px=0, cursor_response=effects.CameraCursorResponse(tilt_limit_deg=18)),
        sheet=effects.Sheet(shape='saddle', ripple=1, shapes=effects.SheetShapes(saddle=effects.SheetShapesSaddle(curvature_deg=5))),
        typing=effects.Typing(sheet_splash=effects.TypingSheetSplash(scale=0.5), particles='sparks', combo=True),
    ),
    enter_duration=0.8,
    idle_after=1.5,
    leave_duration=2.5,
)
comfy = effects.Behavior(
    idle=effects.Frame(sheet=effects.Sheet(ripple=0.25)),
    typing=effects.Frame(
        camera=effects.Camera(zoom=1.3, drift_px=4, drift_speed=2, shake_px=0, cursor_response=effects.CameraCursorResponse(tilt_limit_deg=4)),
        sheet=effects.Sheet(shape='saddle', ripple=0.125, shapes=effects.SheetShapes(saddle=effects.SheetShapesSaddle(curvature_deg=0.2))),
        typing=effects.Typing(sheet_splash=effects.TypingSheetSplash(scale=0.25), particles='sparks', combo=True),
    ),
    enter_duration=0.8,
    idle_after=1.5,
    leave_duration=2.5,
)

effects.setup(
    animate='always',
    camera=effects.Camera(left_preserving_cursor_follow_threshold=0.7, overscroll=1.0),
    lighting=effects.Lighting(strength=1.8, minimum=0, maximum=1.4, shadow_color='#6f5fa8'),
    dof_blur=effects.DofBlur(strength=0.5),
    sheet=effects.Sheet(ripple_falloff=1.0, edge_shadow=0, corner_radius=0, edge_margin=1024, edge_shadow_width=0, content_gloss=0.5),
    typing=effects.Typing(sheet_splash=effects.TypingSheetSplash(speed=900, life=1.1)),
    images=effects.Images(lift=0.08, tilt_scale=1.5),
    particles={'particles': {'life_min': 0.9, 'life_max': 1.6}},
    rain=effects.Rain(opacity=1.0, intensity=1.6),
    behavior=exaggerated,
)

_comfy = False


def toggle_comfy():
    global _comfy
    _comfy = not _comfy
    effects.configure(behavior=comfy if _comfy else exaggerated)
    effects.enable()


def follow_camera():
    effects.configure(behavior=follow)
    effects.enable()

# Terminal
kinetty.opts.terminal.watcher = ["camera_watcher.py"]
kinetty.opts.terminal.font_family = "JetBrainsMono Nerd Font Mono"
kinetty.opts.terminal.font_size = 14.1
kinetty.opts.terminal.symbol_map = [
    SymbolMap(
        font='JetBrainsMono Nerd Font',
        ranges=[
            (0xE000, 0xE00A), (0xE0A0, 0xE0A2), 0xE0A3,
            (0xE0B0, 0xE0B3), (0xE0B4, 0xE0C8), 0xE0CA,
            (0xE0CC, 0xE0D7), (0xE200, 0xE2A9), (0xE300, 0xE3E3),
            (0xE5FA, 0xE6B7), (0xE700, 0xE8EF), (0xEA60, 0xEC1E),
            (0xED00, 0xEFCE), (0xF000, 0xF2FF), (0xF300, 0xF381),
            (0xF400, 0xF533), (0xF0001, 0xF1AF0),
        ],
    ),
    SymbolMap(
        font='Noto Color Emoji',
        ranges=[
            (0x1F000, 0x1FAFF), (0x1F1E6, 0x1F1FF),
        ],
    ),
    SymbolMap(
        font='JetBrainsMono Nerd Font',
        ranges=[
            0x2022, 0x2191, 0x2193,
            0x2197, 0x2198, (0x23FB, 0x23FE),
            0x25AA, 0x25AB, 0x2665,
            0x26A0, 0x2713, 0x2B58,
        ],
    ),
]
kinetty.opts.terminal.undercurl_style = "thick-sparse"
kinetty.opts.terminal.repaint_delay = 8
kinetty.opts.terminal.window_padding_width = 8
kinetty.opts.terminal.background_opacity = 0.85
kinetty.opts.terminal.cursor_trail = 3
kinetty.opts.terminal.cursor_trail_decay = CursorTrailDecay(fast=0.1, slow=0.4)
kinetty.opts.terminal.cursor_trail_start_threshold = CursorTrailThreshold(x=2, y=2)
kinetty.opts.terminal.cursor_trail_color = "#c397d8"
kinetty.opts.terminal.scrollback_lines = 30000
kinetty.opts.terminal.scrollbar = "always"
kinetty.opts.terminal.scrollbar_handle_color = "#5b5072"
kinetty.opts.terminal.scrollbar_handle_opacity = 1.0
kinetty.opts.terminal.scrollbar_track_color = "#3b3052"
kinetty.opts.terminal.scrollbar_width = 0.75
kinetty.opts.terminal.shell_integration = "no-title"
kinetty.opts.terminal.allow_remote_control = "socket-only"
kinetty.opts.terminal.listen_on = "unix:/tmp/kitty"
kinetty.opts.terminal.tab_bar_edge = "top"
kinetty.opts.terminal.tab_bar_min_tabs = 1
kinetty.opts.terminal.tab_bar_style = "powerline"
kinetty.opts.terminal.tab_powerline_style = "round"
kinetty.opts.terminal.tab_title_template = (
    "\"{index}: {tab.progress_percent}{(lambda t, n: t if t[:1] not in ('~', '/') or wcswidth(t) <= n else "
    "'…' + t[wcswidth(t) - n + 1:])(title.split(':', 1)[-1] if '@' in title.split(':', 1)[0] else title, "
    'max_title_length - len(str(index)) - 4 - wcswidth(tab.progress_percent))}"'
)
kinetty.opts.terminal.tab_bar_show_new_tab_button = True
kinetty.opts.terminal.tab_bar_background = "#0b0022"
kinetty.opts.terminal.tab_bar_margin_color = "#0b0022"
kinetty.opts.terminal.active_tab_background = "#5b5072"
kinetty.opts.terminal.active_tab_foreground = "#c0c0c0"
kinetty.opts.terminal.active_tab_font_style = "normal"
kinetty.opts.terminal.inactive_tab_background = "#3b3052"
kinetty.opts.terminal.inactive_tab_foreground = "#a0a0a0"
kinetty.opts.terminal.background = "#282c34"
kinetty.opts.terminal.foreground = "#ffffff"
kinetty.opts.terminal.selection_background = "#7f6699"
kinetty.opts.terminal.selection_foreground = None
kinetty.opts.terminal.colors = {
    0: "#1d1f21",
    1: "#cc6666",
    2: "#b5bd68",
    3: "#f0c674",
    4: "#81a2be",
    5: "#b294bb",
    6: "#8abeb7",
    7: "#c5c8c6",
    8: "#666666",
    9: "#d54e53",
    10: "#b9ca4a",
    11: "#e7c547",
    12: "#7aa6da",
    13: "#c397d8",
    14: "#70c0b1",
    15: "#eaeaea",
}
kinetty.opts.terminal.enabled_layouts = "splits"
keymap.set("cmd+shift+r", actions.load_config_file)
keymap.set("cmd+shift+f2", actions.previous_tab)
keymap.set("cmd+shift+f3", actions.previous_tab)
keymap.set("cmd+shift+f6", actions.next_tab)
keymap.set("ctrl+shift+left", actions.move_tab_backward)
keymap.set("ctrl+shift+right", actions.move_tab_forward)
keymap.set("cmd+shift+b", "remote_control_script toggle-tab-bar-edge.sh")
keymap.set("cmd+1", partial(actions.goto_tab, 1))
keymap.set("cmd+2", partial(actions.goto_tab, 2))
keymap.set("cmd+3", partial(actions.goto_tab, 3))
keymap.set("cmd+4", partial(actions.goto_tab, 4))
keymap.set("cmd+5", partial(actions.goto_tab, 5))
keymap.set("cmd+6", partial(actions.goto_tab, 6))
keymap.set("cmd+7", partial(actions.goto_tab, 7))
keymap.set("cmd+8", partial(actions.goto_tab, 8))
keymap.set("cmd+9", partial(actions.goto_tab, 9))
keymap.set("cmd+shift+d", actions.detach_window)
keymap.set("cmd+shift+c", partial(actions.detach_window, "new-tab"))
keymap.set(
    "ctrl+alt+shift+backslash",
    partial(actions.launch, location="vsplit", cwd="current"),
)
keymap.set(
    "ctrl+alt+shift+minus", partial(actions.launch, location="hsplit", cwd="current")
)
keymap.set("shift+up", partial(actions.scroll_to_prompt, -1))
keymap.set("shift+down", partial(actions.scroll_to_prompt, 1))
keymap.set(
    "cmd+shift+e",
    partial(actions.kinetten, "hints", "--customize-processing", "hyperlinks.py"),
)
keymap.set(
    "ctrl+shift+space",
    partial(
        actions.kinetten,
        "hints",
        "--customize-processing",
        "quick_select.py",
        "--program",
        "@",
        "--alphabet",
        "asdfqwerzxcvjklmiuopghtybn",
        "--hints-offset",
        "0",
        "--prefix-free",
    ),
)
keymap.set("cmd+ctrl+shift+space", "discard_event")

if sys.platform == "darwin":
    kinetty.opts.terminal.macos_font_backend = "freetype"
    kinetty.opts.terminal.macos_option_as_alt = "left"
    kinetty.opts.terminal.macos_titlebar_color = "background"
    kinetty.opts.terminal.macos_show_window_title_in = None
    kinetty.opts.terminal.text_composition_strategy = TextComposition(gamma=1.7, contrast=30)
    kinetty.opts.terminal.env = {
        'PATH': '/opt/homebrew/bin:/opt/homebrew/sbin:/Applications/kitty.app/Contents/MacOS:/usr/bin:/bin:/usr/sbin:/sbin',
    }
    keymap.delete("ctrl+shift+equal")
    keymap.delete("ctrl+shift+plus")
    keymap.delete("ctrl+shift+kp_add")
    keymap.delete("ctrl+shift+minus")
    keymap.delete("ctrl+shift+kp_subtract")
    kinetty.opts.terminal.menu_map.extend(
        [
            MenuMap(path=['View', 'Change preset to comfy'], action=toggle_comfy),
            MenuMap(path=['View', 'Camera: Follow'], action=follow_camera),
            MenuMap(path=['View', 'Camera: Off'], action=effects.disable),
            MenuMap(path=['View', 'Toggle Sheet Tilt'], action=effects.toggle_sheet_tilt),
            MenuMap(path=['View', 'Toggle Typing Shake'], action=effects.toggle_camera_shake),
            MenuMap(path=['View', 'Toggle Typing Particles'], action=effects.toggle_typing_particles),
            MenuMap(path=['View', 'Toggle Typing Splash'], action=effects.toggle_typing_splash),
            MenuMap(path=['View', 'Toggle Idle Ripple'], action=effects.toggle_idle_ripple),
            MenuMap(path=['View', 'Toggle Typing Ripple'], action=effects.toggle_typing_ripple),
            MenuMap(path=['View', 'Effects', 'Weather', 'Off'], action=partial(particles.set_field, None)),
            MenuMap(path=['View', 'Effects', 'Weather', 'Rain'], action=effects.set_rain),
            MenuMap(path=['View', 'Effects', 'Weather', 'Snow'], action=snow.enable),
            MenuMap(path=['View', 'Effects', 'Typing Particles', 'Off'], action=partial(effects.set_typing_particles, 'none')),
            MenuMap(path=['View', 'Effects', 'Typing Particles', 'Particles'], action=partial(effects.set_typing_particles, 'particles')),
            MenuMap(path=['View', 'Effects', 'Typing Particles', 'Sparks'], action=partial(effects.set_typing_particles, 'sparks')),
            MenuMap(path=['View', 'Camera Zoom In (+50%)'], action=partial(effects.set_zoom, 0.5, relative=True)),
            MenuMap(path=['View', 'Camera Zoom Out (-50%)'], action=partial(effects.set_zoom, -0.5, relative=True)),
            MenuMap(path=['View', 'Camera Zoom', '150%'], action=partial(effects.set_zoom, 1.5)),
            MenuMap(path=['View', 'Camera Zoom', '200%'], action=partial(effects.set_zoom, 2.0)),
            MenuMap(path=['View', 'Camera Zoom', '300%'], action=partial(effects.set_zoom, 3.0)),
            MenuMap(path=['View', 'Toggle Vertical Tabs'], action='remote_control_script toggle-tab-bar-edge.sh'),
            MenuMap(path=['View', 'Sidebar: Small'], action='remote_control load-config -o tab_title_max_length=12 -o tab_bar_edge=left'),
            MenuMap(path=['View', 'Sidebar: Medium'], action='remote_control load-config -o tab_title_max_length=20 -o tab_bar_edge=left'),
            MenuMap(path=['View', 'Sidebar: Large'], action='remote_control load-config -o tab_title_max_length=32 -o tab_bar_edge=left'),
        ]
    )


import silksong_worlds
import volleyball
import worlds

worlds.setup(assets="/Users/kiyoon/project/wezterm-gureum/kitty/kinetty/assets")
volleyball.setup(assets="/Users/kiyoon/project/wezterm-gureum/kitty/kinetty/assets")
silksong_worlds.setup(assets="/Users/kiyoon/project/wezterm-gureum/kitty/kinetty/assets/silksong")
