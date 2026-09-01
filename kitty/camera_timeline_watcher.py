from __future__ import annotations

import os
from typing import TYPE_CHECKING, Any

from kitty.constants import kitten_exe
from kitty.utils import log_error

if TYPE_CHECKING:
    from kitty.boss import Boss
    from kitty.window import Window


_TIMELINES = {
    'nvim-tour': os.path.join(os.path.dirname(__file__), 'camera-timelines', 'nvim-tour.json'),
}
_in_flight: set[int] = set()


def on_set_user_var(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    if data.get('key') != 'camera_timeline':
        return
    timeline = _TIMELINES.get(data.get('value'))
    window_id = window.id
    if timeline is None or window_id in _in_flight:
        return

    def on_death(exit_status: int, error: Exception | None) -> None:
        _in_flight.discard(window_id)
        if error is not None:
            log_error(f'Failed to start camera timeline for window {window_id}: {error}')
        elif exit_status != 0:
            log_error(f'Camera timeline for window {window_id} exited with status {exit_status}')

    _in_flight.add(window_id)
    try:
        boss.run_background_process(
            [kitten_exe(), 'camera-timeline', '--match', f'id:{window_id}', timeline],
            allow_remote_control=True,
            notify_on_death=on_death,
        )
    except Exception as error:
        _in_flight.discard(window_id)
        log_error(f'Failed to start camera timeline for window {window_id}: {error}')
