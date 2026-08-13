# Godot Color Grading
Flexible set of color filters utilizing dedicated color spaces.

Features:
- Shadows, midtones and highlights adjustment
- Color tint
- Vibrance
- Brightness
- Curves

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/F2F5KVSB)
![Vibrant](Screenshots/Vibrant.jpg)
![Moody](Screenshots/Moody.jpg)
![Strong](Screenshots/Subway.jpg)

## Night color
Simulation of color perception in darkness where your eyes are most sensitive to blue color while other colors appear darker.

![Night color](Screenshots/Night.jpg)

## Local contrast
Enhance details and soft values of the scene with local contrast filter.
![Local contrast](<Screenshots/Local contrast.jpg>)

## Usage
Enable plugin in `Project settings -> Plugins -> Color grading`

Add new `Compositor` resource in your `WorldEnvironment` node if none is present.

Effects are available under `ColorGrading` and `LocalContrast` options.