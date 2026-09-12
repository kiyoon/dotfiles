from __future__ import annotations

from typing import TYPE_CHECKING, Any

from kitty.camera import CameraAction, CameraPose, Keyframe, ReturnTo
from kitty.utils import log_error

if TYPE_CHECKING:
    from kitty.boss import Boss
    from kitty.window import Window


_NVIM_TOUR = CameraAction(
    fps=30,
    keyframes=[
        Keyframe(frame=15, pose=CameraPose(zoom=1.5, x='center', y='top', tilt_x=2, tilt_y=-1)),
        Keyframe(frame=45, pose=CameraPose(zoom=1.5, x='center', y='bottom', tilt_x=-2, tilt_y=1)),
    ],
)


def on_set_user_var(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    if data.get('key') != 'camera_effect' or data.get('value') != 'nvim-tour':
        return
    try:
        # Native playback owns all frames, segment boundaries and restoration.
        camera = window.camera
        previous = camera.capture()
        action = _NVIM_TOUR.model_copy(update={'finish': ReturnTo(previous, duration=0.8)})
        camera.play(action, lease=30, cancel_on_input=False, pan_space='viewport')
    except ValueError as error:
        if 'held by another token' not in str(error) and 'camera is already owned' not in str(error):
            log_error(f'Nvim camera effect for window {window.id} stopped: {error}')
