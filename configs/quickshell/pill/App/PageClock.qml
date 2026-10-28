import QtQuick
import "../Singletons"
import "PillDefaults.js" as Defaults

AppPage {
    id: page
    pageId: "clock"

    function set(k, v) {
        if (!Defaults.same(Flags[k], v))
            Flags[k] = Defaults.clone(v);
    }

    function reset() {
        for (const k of Defaults.clockKeys)
            set(k, Defaults.flags[k]);
    }

    AppGroup {
        title: "Clock"

        AppRow {
            label: "Format"
            sub: "24 hours, or 12 with am and pm"
            key: "clock.format"

            AppSeg {
                s: page.s
                options: [{ label: "24h", value: false }, { label: "12h", value: true }]
                value: Flags.time12h
                onPicked: (v) => Flags.time12h = v
            }
        }

        AppRow {
            label: "Seconds"
            sub: "The clock ticks every second"
            key: "clock.seconds"

            AppToggle {
                s: page.s
                checked: Flags.clockSeconds
                onToggled: (on) => Flags.clockSeconds = on
            }
        }
    }

    AppGroup {
        title: "Date"

        AppRow {
            label: "Date style"
            sub: "Under the clock on hover, and in the date module"
            key: "clock.dateStyle"

            AppSeg {
                s: page.s
                options: Defaults.dateStyles.map(st => ({ label: Clock.dateFor(st, Flags.dateLang), value: st }))
                value: Flags.dateStyle
                onPicked: (v) => Flags.dateStyle = v
            }
        }

        AppRow {
            label: "Language"
            sub: "Day and month names"
            key: "clock.lang"

            AppSeg {
                s: page.s
                options: [{ label: "English", value: "en" }, { label: "Deutsch", value: "de" }]
                value: Flags.dateLang
                onPicked: (v) => Flags.dateLang = v
            }
        }

        advanced: [
            AppRow {
                label: "Week starts"
                sub: "First day of the week in the calendar"
                key: "clock.weekStart"

                AppSeg {
                    s: page.s
                    options: [{ label: "Monday", value: "mon" }, { label: "Sunday", value: "sun" }]
                    value: Flags.weekStart
                    onPicked: (v) => Flags.weekStart = v
                }
            },

            AppRow {
                block: true

                PillMonthGrid {
                    s: page.s
                }
            }
        ]
    }
}
