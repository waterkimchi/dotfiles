import datetime
import locale

from kitty.boss import get_boss
from kitty.fast_data_types import Screen, add_timer
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    Formatter,
    TabBarData,
    as_rgb,
    draw_attributed_string,
    draw_tab_with_powerline,
)

# Colors and separators
DOT_SEP, SLANTED_SEP = "·", ""
RHS_FG, TEXT_FG = as_rgb(0xFE8019), as_rgb(0xCDD6F4)

# The global timer
_timer = None

# Revert LC_TIME to "C" for cross-platform output compatibility
locale.setlocale(locale.LC_TIME, "C")


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    # Initialize the timer if we haven't already done so
    global _timer
    if not _timer:
        _timer = add_timer(_redraw, 2.0, True)

    # First, draw the lhs as defined in the config
    draw_tab_with_powerline(
        draw_data, screen, tab, before, max_title_length, index, is_last, extra_data
    )

    # Now draw our dynamically defined rhs
    if is_last:
        draw_rhs(draw_data, screen, tab)

    # Return the final cursor position as required
    return screen.cursor.x


def draw_rhs(draw_data: DrawData, screen: Screen, tab: TabBarData):
    # The tabs may have left some formats enabled. Disable them now.
    draw_attributed_string(Formatter.reset, screen)

    # Drop cells that won't fit
    cells = create_cells(tab)[:2]
    padding = screen.columns - screen.cursor.x - sum(len(c) + 3 for c in cells)

    # Apply padding
    if padding > 0:
        screen.draw(" " * padding)

    rhs_bg = as_rgb(int(draw_data.default_bg))
    for i, cell in enumerate(cells):
        # Now draw the cells (with separators)
        # - The first cell shall display the current tab's title with a lavender foreground
        # - The second cell shall display the current date with a lavender foreground
        # - No other cells shall be defined; they will be silently ignored.
        screen.cursor.fg, screen.cursor.bg = (
            (rhs_bg, rhs_bg) if i == 0 else (RHS_FG, rhs_bg)
        )
        screen.draw(SLANTED_SEP if i == 0 else DOT_SEP)

        # The content (should be in lavender)
        screen.cursor.fg = RHS_FG
        screen.draw(f" {cell} ")


def create_cells(tab: TabBarData) -> list[str]:
    now = datetime.datetime.now().strftime("%a %b %d %H:%M")
    title = (
        tab.title[:30] + "…"
        if len(tab.title) > 30
        else tab.title.center(6 if len(tab.title) % 2 == 0 else 5)
    )
    return [title, now]


def _redraw(_):
    # Mark all tab bars as dirty to trigger a redraw
    for tm in get_boss().all_tab_managers:
        tm.mark_tab_bar_dirty()
