const THREE = require('./.hyper_plugins/node_modules/three')
const {
  EffectPass,
  Effect,
  BloomEffect,
  ScanlineEffect,
  BlendFunction,
  KernelSize,
} = require('./.hyper_plugins/node_modules/postprocessing')

// http://jeromeetienne.github.io/threex.badtvpproc/examples/felixturner_badtv.html

class CurvedMonitor extends Effect {
  constructor({
    magnitude = 0.15, // how far the center of the "monitor" points out
    cutShort = 0.1, // how far along the the easing curve we travel...I think...
  } = {}) {
    super(
      'CurvedMonitor',
      `
      uniform float magnitude;
      uniform float cutShort;

      // pythagorean theorem
      float distanceFromOrigin(vec2 point, vec2 origin) {
        float deltaX = (point.x - origin.x);
        float deltaY = (point.y - origin.y);
        return sqrt(pow(deltaX, 2.0) + pow(deltaY, 2.0));
      }

      float easeInQuart(float time, float begin, float change, float duration) {
        return change * (time /= duration) * time * time * time + begin;
      }

      void mainUv(inout vec2 uv) {
        vec2 screenCenter = vec2(0.5, 0.5);
        float radius = 0.5;

        vec2 coords = vec2(uv.x - screenCenter.x, uv.y - screenCenter.y);

        float distFromOrigin = distanceFromOrigin(uv, screenCenter);

        float scalar = easeInQuart(distFromOrigin, 1.0 / cutShort - magnitude, magnitude, radius);
        coords *= scalar * cutShort;

        uv = vec2(coords.x + screenCenter.x, coords.y + screenCenter.y);
      }
    `,
      {
        uniforms: new Map([
          ['magnitude', new THREE.Uniform(magnitude)],
          ['cutShort', new THREE.Uniform(cutShort)],
        ]),
      },
    )
  }
}

class Sampling extends Effect {
  constructor({} = {}) {
    super(
      'Sampling',
      `
      // if uv is outside the bounds of 0 to 1, instead sets the output color to the
      // "outOfBoundsColor" define.

      // defaults to black
      #ifndef outOfBoundsColor
      #define outOfBoundsColor vec4(0.0, 0.0, 0.0, 1.0)
      #endif

      void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
        float isOutOfBounds = step(0.0, uv.x) * step(-1.0, -uv.x) * step(0.0, uv.y) * step(-1.0, -uv.y);
        outputColor = mix(outOfBoundsColor, inputColor, isOutOfBounds);
      }
    `,
      {
        blendFunction: BlendFunction.NORMAL,
      },
    )
  }
}

module.exports = ({ hyperTerm, xTerm }) => {
  const effects = []

  // const bloom = new BloomEffect({
  //   kernelSize: KernelSize.LARGE,
  //   distinction: 1,
  //   blendFunction: BlendFunction.ADD,
  // })
  // // bloom.blendMode.opacity.value =
  // effects.push(bloom)

  // const scanline = new ScanlineEffect({ density: 2 })
  // effects.push(scanline)

  //  TODO burn in!!!!!

  // TODO static noise

  // TODO jitter

  // TODO flickering

  // TODO add sepia but green
  // effects.push(new SepiaEffect({ intensity: 0.5 }))

  // TODO RGB shift?

  // const curvedMonitor = new CurvedMonitor()
  // effects.push(curvedMonitor)

  // // removes artifacts from the CurvedMonitor effect
  // const sampling = new Sampling()
  // effects.push(sampling)

  return { pass: new EffectPass(null, ...effects) }
}
