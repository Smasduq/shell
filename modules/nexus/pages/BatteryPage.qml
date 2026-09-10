pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Battery")

    function formatSeconds(s: int): string {
        const day = Math.floor(s / 86400);
        const hr = Math.floor(s / 3600) % 24;
        const min = Math.floor(s / 60) % 60;

        let comps = [];
        if (day > 0)
            comps.push(Tr.trN("%n day", "%n days", day));
        if (hr > 0)
            comps.push(Tr.trN("%n hour", "%n hours", hr));
        if (min > 0)
            comps.push(Tr.trN("%n min", "%n mins", min));

        return comps.join(Tr.trCtx(", ", "duration component separator"));
    }

    function batteryStateString(): string {
        if (!UPower.displayDevice.isLaptopBattery)
            return Tr.tr("No battery detected");
        switch (UPower.displayDevice.state) {
        case BatteryState.Charging:
            return Tr.tr("Charging");
        case BatteryState.FullyCharged:
            return Tr.tr("Fully charged");
        case BatteryState.PendingCharge:
            return Tr.tr("Pending charge");
        case BatteryState.Discharging:
            return Tr.tr("Discharging");
        default:
            return Tr.tr("Unknown");
        }
    }

    function profileString(): string {
        switch (PowerProfiles.profile) {
        case PowerProfile.Balanced:
            return Tr.trCtx("Balanced", "power profile");
        case PowerProfile.Performance:
            return Tr.trCtx("Performance", "power profile");
        case PowerProfile.PowerSaver:
            return Tr.trCtx("Power saver", "power profile");
        default:
            return Tr.trCtx("Unknown", "power profile");
        }
    }

    function findLockTimeout(): int {
        const timeouts = GlobalConfig.general.idle.timeouts;
        for (let i = 0; i < timeouts.length; i++) {
            if (timeouts[i].idleAction === "lock")
                return timeouts[i].timeout;
        }
        return 180;
    }

    function updateLockTimeout(seconds: int): void {
        const timeouts = [...GlobalConfig.general.idle.timeouts];
        for (let i = 0; i < timeouts.length; i++) {
            if (timeouts[i].idleAction === "lock") {
                const entry = Object.assign({}, timeouts[i]);
                entry.timeout = seconds;
                timeouts[i] = entry;
                break;
            }
        }
        GlobalConfig.general.idle.timeouts = timeouts;
    }

    function batteryIcon(): string {
        if (!UPower.displayDevice.isLaptopBattery)
            return "battery_unknown";
        const p = Math.round(UPower.displayDevice.percentage * 100);
        if (UPower.onBattery) {
            if (p > 80)
                return "battery_5_bar";
            if (p > 60)
                return "battery_4_bar";
            if (p > 40)
                return "battery_3_bar";
            if (p > 20)
                return "battery_2_bar";
            return "battery_1_bar";
        }
        return "battery_charging_full";
    }

    readonly property list<MenuItem> profileItems: [
        MenuItem {
            text: Tr.trCtx("Power saver", "power profile")
            icon: "energy_savings_leaf"
        },
        MenuItem {
            text: Tr.trCtx("Balanced", "power profile")
            icon: "balance"
        },
        MenuItem {
            text: Tr.trCtx("Performance", "power profile")
            icon: "rocket_launch"
        }
    ]

    readonly property list<int> profileValues: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Battery status
        SectionHeader {
            first: true
            text: Tr.tr("Battery status")
        }

        InfoRow {
            first: true
            label: Tr.tr("Battery level")
            icon: root.batteryIcon()
            value: UPower.displayDevice.isLaptopBattery ? Math.round(UPower.displayDevice.percentage * 100) + "%" : Tr.tr("N/A")
        }

        InfoRow {
            label: Tr.tr("Status")
            value: root.batteryStateString()
        }

        InfoRow {
            label: UPower.onBattery ? Tr.tr("Time remaining") : Tr.tr("Time until full")
            value: {
                if (!UPower.displayDevice.isLaptopBattery)
                    return Tr.tr("N/A");
                const secs = UPower.onBattery ? UPower.displayDevice.timeToEmpty : UPower.displayDevice.timeToFull;
                return secs > 0 ? root.formatSeconds(secs) : Tr.tr("Calculating...");
            }
        }

        InfoRow {
            last: true
            label: Tr.tr("Power profile")
            value: root.profileString()
        }

        // Power profile
        SectionHeader {
            text: Tr.tr("Power profile")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("Power profile")
            subtext: Tr.tr("Balanced is recommended for most users")
            menuItems: root.profileItems
            active: root.profileItems[root.profileValues.indexOf(PowerProfiles.profile)]
            onSelected: item => {
                const idx = root.profileItems.indexOf(item);
                if (idx >= 0)
                    PowerProfiles.profile = root.profileValues[idx];
            }
        }

        // Idle behaviour
        SectionHeader {
            text: Tr.tr("Idle behaviour")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Lock before sleep")
            subtext: Tr.tr("Lock the screen before the system suspends")
            checked: GlobalConfig.general.idle.lockBeforeSleep
            onToggled: GlobalConfig.general.idle.lockBeforeSleep = checked
        }

        ToggleRow {
            text: Tr.tr("Inhibit when audio playing")
            subtext: Tr.tr("Prevent idle actions while media is playing")
            checked: GlobalConfig.general.idle.inhibitWhenAudio
            onToggled: GlobalConfig.general.idle.inhibitWhenAudio = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Inhibit when charging")
            subtext: Tr.tr("Prevent idle actions while plugged in")
            checked: GlobalConfig.general.idle.inhibitWhenCharging
            onToggled: GlobalConfig.general.idle.inhibitWhenCharging = checked
        }

        // Screen timeout
        SectionHeader {
            text: Tr.tr("Screen timeout")
        }

        StepperRow {
            first: true
            last: true
            label: Tr.tr("Lock after")
            subtext: Tr.tr("Minutes of inactivity before the screen locks")
            value: Math.round(root.findLockTimeout() / 60)
            from: 1
            to: 30
            stepSize: 1
            onMoved: v => root.updateLockTimeout(Math.round(v) * 60)
        }

        // Battery warnings
        SectionHeader {
            text: Tr.tr("Battery warnings")
        }

        Repeater {
            model: GlobalConfig.general.battery.warnLevels

            InfoRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === GlobalConfig.general.battery.warnLevels.length - 1
                label: modelData.title ?? Tr.tr("Warning")
                icon: modelData.icon ?? "warning"
                subtext: modelData.message ?? ""
                value: modelData.level + "%"
            }
        }

        ToggleRow {
            text: Tr.tr("Auto-hibernate at critical level")
            subtext: Tr.tr("Hibernate when battery drops below the critical threshold")
            checked: GlobalConfig.general.battery.criticalLevel > 0
            onToggled: GlobalConfig.general.battery.criticalLevel = checked ? 3 : 0
        }

        StepperRow {
            last: true
            label: Tr.tr("Critical level")
            subtext: Tr.tr("Battery percentage that triggers auto-hibernate")
            value: GlobalConfig.general.battery.criticalLevel
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.general.battery.criticalLevel = Math.round(v)
        }
    }
}
