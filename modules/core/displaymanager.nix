{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  pixieBase = inputs.pixie-sddm.packages.${system}.pixie-sddm.override {
    autoColor = false;
    accentColor = "#722F37";
    backgroundColor = "#0A0A0A";
  };

  clockQml = pkgs.writeText "Clock.qml" ''
    /**
     * Pixie SDDM - Clock Component
     * Author: xCaptaiN09
     * Modified: side-by-side HH:MM layout instead of stacked digits
     */
    import QtQuick
    Item {
        id: clock
        property string backgroundSource: ""
        property color defaultHoursColor: "#AED68A"
        property color defaultMinutesColor: "#D4E4BC"
        property string fontFamily: "FlexRounded" // Overridden by Main.qml
        property color baseAccent: config.accentColor
        property color smartHoursColor: defaultHoursColor
        property color smartMinutesColor: defaultMinutesColor
        property string hourStr: ""
        property string minuteStr: ""

        function updateTime() {
            var date = new Date();
            var hours = date.getHours();
            var minutes = date.getMinutes();
            if (config.use24HourClock !== "true") {
                hours = hours % 12;
                if (hours === 0) hours = 12;
            }
            clock.hourStr = hours < 10 ? "0" + hours : "" + hours;
            clock.minuteStr = minutes < 10 ? "0" + minutes : "" + minutes;
        }

        function updateColors() {
            var base = clock.baseAccent;
            if (base.hsvSaturation < 0.15) {
                clock.smartHoursColor = Qt.lighter(base, 1.3);
                clock.smartMinutesColor = Qt.darker(base, 1.4);
                return;
            }
            if (base.hsvValue < 0.5) {
                clock.smartHoursColor = Qt.hsva(base.hsvHue, 0.7, 0.9, 1.0);
                clock.smartMinutesColor = Qt.hsva(base.hsvHue, 0.45, 0.85, 1.0);
            } else if (base.hsvValue > 0.8 && base.hsvSaturation < 0.2) {
                clock.smartHoursColor = Qt.hsva(base.hsvHue, 0.8, 0.7, 1.0);
                clock.smartMinutesColor = Qt.hsva(base.hsvHue, 0.5, 0.75, 1.0);
            } else {
                clock.smartHoursColor = Qt.hsva(base.hsvHue, Math.min(1.0, base.hsvSaturation * 1.3), 0.95, 1.0);
                clock.smartMinutesColor = Qt.hsva(base.hsvHue, Math.min(1.0, base.hsvSaturation * 0.75), 0.92, 1.0);
            }
        }

        onBaseAccentChanged: updateColors()
        Component.onCompleted: {
            updateColors();
            updateTime();
        }

        Row {
            anchors.centerIn: parent
            spacing: 20

            Text {
                text: clock.hourStr
                color: clock.smartHoursColor
                font.pixelSize: 140
                font.family: clock.fontFamily
                font.weight: Font.Medium
                antialiasing: true
            }
            Text {
                text: ":"
                color: clock.smartHoursColor
                font.pixelSize: 140
                font.family: clock.fontFamily
                font.weight: Font.Medium
                antialiasing: true
            }
            Text {
                text: clock.minuteStr
                color: clock.smartMinutesColor
                font.pixelSize: 140
                font.family: clock.fontFamily
                font.weight: Font.Medium
                antialiasing: true
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: updateTime()
        }
    }
  '';

  pixieThemed = pkgs.runCommand "pixie-sddm-themed" { nativeBuildInputs = [ pkgs.gnused ]; } ''
    mkdir -p $out
    cp -r ${pixieBase}/* $out/
    chmod -R u+w $out

    install -Dm444 ${../../assets/sddm/burzum-lockscreen.jpg} $out/share/sddm/themes/pixie/assets/background.jpg
    install -Dm444 ${../../assets/sddm/avatar-lockscreen.jpg} $out/share/sddm/themes/pixie/assets/avatar.jpg
    install -Dm444 ${clockQml} $out/share/sddm/themes/pixie/components/Clock.qml

    sed -z -i 's/id: mainClock\n            anchors\.centerIn: parent/id: mainClock\n            anchors.horizontalCenter: parent.horizontalCenter\n            anchors.bottom: parent.bottom\n            anchors.bottomMargin: 220/' \
      $out/share/sddm/themes/pixie/Main.qml
  '';
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "pixie";
    package = pkgs.kdePackages.sddm;

    extraPackages = [
      pkgs.kdePackages.qtsvg
      pkgs.kdePackages.qtdeclarative
      pkgs.kdePackages.qt5compat
    ];
  };

  environment.systemPackages = [ pixieThemed ];
}
