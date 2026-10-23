import Quickshell.Io

/**
 * A Process whose rerun() while running queues one more run instead of being dropped.
 */
Process {
    property bool again: false

    function rerun() {
        if (running)
            again = true;
        else
            running = true;
    }

    onRunningChanged: if (!running && again) {
        again = false;
        running = true;
    }
}
