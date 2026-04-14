package dev.zide.terminal.selection;

import android.content.Context;
import android.widget.FrameLayout;

import dev.zide.terminal.host.interaction.SelectionBridge;
import dev.zide.terminal.host.interaction.SelectionInteractionBridge;

/** Creates selection controllers for a terminal surface widget instance. */
public final class TerminalSelectionControllerFactory {
    /** Widget host callbacks required by selection controller wiring. */
    public interface Host {
        int productViewportWidthPx();

        int productViewportHeightPx();

        void stopScrollbackFling();

        void refreshProductScrollOverlay();

        void reevaluateProductFrameLoop();

        void appendEvent(String event);

        boolean nativeLoaded();

        int beginWordSelectionAtVisibleCell(int row, int col);

        int extendSelectionGestureToVisibleCell(int row, int col);

        int finishSelectionGesture();

        int clearSelection();

        int updateSelectionStartAtVisibleCell(int row, int col);

        int updateSelectionEndAtVisibleCell(int row, int col);

        boolean currentSelectionActive();

        int currentSelectionRectLeft();

        int currentSelectionRectTop();

        int currentSelectionRectRight();

        int currentSelectionRectBottom();

        int currentSelectionStartRectLeft();

        int currentSelectionStartRectTop();

        int currentSelectionStartRectRight();

        int currentSelectionStartRectBottom();

        int currentSelectionEndRectLeft();

        int currentSelectionEndRectTop();

        int currentSelectionEndRectRight();

        int currentSelectionEndRectBottom();

        byte[] currentSelectionTextBytes();

        int currentVisibleRows();

        int currentVisibleCols();

        int currentScrollbackCount();

        int currentScrollbackOffset();

        int setShellScrollbackOffset(int offsetRows);

        int followShellLiveBottom();
    }

    private TerminalSelectionControllerFactory() {
    }

    public static TerminalSelectionController create(Context context, FrameLayout productSurfaceContainer, Host host) {
        return new TerminalSelectionController(
                new SelectionInteractionBridge(
                        context,
                        productSurfaceContainer,
                        new SelectionInteractionBridge.Callbacks() {
                            @Override
                            public int productViewportWidthPx() {
                                return host.productViewportWidthPx();
                            }

                            @Override
                            public int productViewportHeightPx() {
                                return host.productViewportHeightPx();
                            }

                            @Override
                            public void stopScrollbackFling() {
                                host.stopScrollbackFling();
                            }

                            @Override
                            public void refreshProductScrollOverlay() {
                                host.refreshProductScrollOverlay();
                            }

                            @Override
                            public void reevaluateProductFrameLoop() {
                                host.reevaluateProductFrameLoop();
                            }

                            @Override
                            public void appendEvent(String event) {
                                host.appendEvent(event);
                            }
                        }),
                new SelectionBridge(new SelectionBridge.Callbacks() {
                    @Override
                    public boolean nativeLoaded() {
                        return host.nativeLoaded();
                    }

                    @Override
                    public int beginWordSelectionAtVisibleCell(int row, int col) {
                        return host.beginWordSelectionAtVisibleCell(row, col);
                    }

                    @Override
                    public int extendSelectionGestureToVisibleCell(int row, int col) {
                        return host.extendSelectionGestureToVisibleCell(row, col);
                    }

                    @Override
                    public int finishSelectionGesture() {
                        return host.finishSelectionGesture();
                    }

                    @Override
                    public int clearSelection() {
                        return host.clearSelection();
                    }

                    @Override
                    public int updateSelectionStartAtVisibleCell(int row, int col) {
                        return host.updateSelectionStartAtVisibleCell(row, col);
                    }

                    @Override
                    public int updateSelectionEndAtVisibleCell(int row, int col) {
                        return host.updateSelectionEndAtVisibleCell(row, col);
                    }

                    @Override
                    public boolean currentSelectionActive() {
                        return host.currentSelectionActive();
                    }

                    @Override
                    public int currentSelectionRectLeft() {
                        return host.currentSelectionRectLeft();
                    }

                    @Override
                    public int currentSelectionRectTop() {
                        return host.currentSelectionRectTop();
                    }

                    @Override
                    public int currentSelectionRectRight() {
                        return host.currentSelectionRectRight();
                    }

                    @Override
                    public int currentSelectionRectBottom() {
                        return host.currentSelectionRectBottom();
                    }

                    @Override
                    public int currentSelectionStartRectLeft() {
                        return host.currentSelectionStartRectLeft();
                    }

                    @Override
                    public int currentSelectionStartRectTop() {
                        return host.currentSelectionStartRectTop();
                    }

                    @Override
                    public int currentSelectionStartRectRight() {
                        return host.currentSelectionStartRectRight();
                    }

                    @Override
                    public int currentSelectionStartRectBottom() {
                        return host.currentSelectionStartRectBottom();
                    }

                    @Override
                    public int currentSelectionEndRectLeft() {
                        return host.currentSelectionEndRectLeft();
                    }

                    @Override
                    public int currentSelectionEndRectTop() {
                        return host.currentSelectionEndRectTop();
                    }

                    @Override
                    public int currentSelectionEndRectRight() {
                        return host.currentSelectionEndRectRight();
                    }

                    @Override
                    public int currentSelectionEndRectBottom() {
                        return host.currentSelectionEndRectBottom();
                    }

                    @Override
                    public byte[] currentSelectionTextBytes() {
                        return host.currentSelectionTextBytes();
                    }

                    @Override
                    public int currentVisibleRows() {
                        return host.currentVisibleRows();
                    }

                    @Override
                    public int currentVisibleCols() {
                        return host.currentVisibleCols();
                    }

                    @Override
                    public int currentScrollbackCount() {
                        return host.currentScrollbackCount();
                    }

                    @Override
                    public int currentScrollbackOffset() {
                        return host.currentScrollbackOffset();
                    }

                    @Override
                    public int setShellScrollbackOffset(int offsetRows) {
                        return host.setShellScrollbackOffset(offsetRows);
                    }

                    @Override
                    public int followShellLiveBottom() {
                        return host.followShellLiveBottom();
                    }
                }));
    }
}
