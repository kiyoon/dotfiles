from __future__ import annotations

from typing import TYPE_CHECKING, Any

from kinetty.camera import CameraAction, CameraPose, CameraShot, Keyframe, ReturnTo
import logging

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
_tours: dict[int, CameraShot] = {}


def on_close(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    _tours.pop(window.id, None)


def on_set_user_var(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    if data.get('key') != 'camera_effect' or data.get('value') not in ('nvim-tour', 'nvim-rest'):
        return
    try:
        if data['value'] == 'nvim-rest':
            tour = _tours.pop(window.id, None)
            if tour is not None:
                try:
                    tour.cancel()
                except ValueError as error:
                    if 'is not the current token' not in str(error):
                        raise
            # Return to configured rest while leaving typing transitions armed.
            window.camera_director('begin', 'nvim-save-rest', 'lease=3 cancel_on_input=no')
            window.camera_director('restore', 'nvim-save-rest', 'target=rest duration=0.6 easing=smoothstep')
            return
        # Native playback owns all frames, segment boundaries and restoration.
        camera = window.world.camera
        previous = camera.capture()
        action = _NVIM_TOUR.model_copy(update={'finish': ReturnTo(previous, duration=0.8)})
        _tours[window.id] = camera.play(action, lease=30, cancel_on_input=False, pan_space='viewport')
    except ValueError as error:
        if 'held by another token' not in str(error) and 'camera is already owned' not in str(error):
            logging.getLogger(__name__).error(f'Nvim camera effect for window {window.id} stopped: {error}')
