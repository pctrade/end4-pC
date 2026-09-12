pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common.widgets

Singleton {
    function getShape(name) {
        switch (name) {
            case "Circle":        return MaterialShape.Shape.Circle
            case "Square":        return MaterialShape.Shape.Square
            case "Slanted":       return MaterialShape.Shape.Slanted
            case "Arch":          return MaterialShape.Shape.Arch
            case "Fan":           return MaterialShape.Shape.Fan
            case "Arrow":         return MaterialShape.Shape.Arrow
            case "SemiCircle":    return MaterialShape.Shape.SemiCircle
            case "Oval":          return MaterialShape.Shape.Oval
            case "Pill":          return MaterialShape.Shape.Pill
            case "Triangle":      return MaterialShape.Shape.Triangle
            case "Diamond":       return MaterialShape.Shape.Diamond
            case "ClamShell":     return MaterialShape.Shape.ClamShell
            case "Pentagon":      return MaterialShape.Shape.Pentagon
            case "Gem":           return MaterialShape.Shape.Gem
            case "Sunny":         return MaterialShape.Shape.Sunny
            case "VerySunny":     return MaterialShape.Shape.VerySunny
            case "Cookie4Sided":  return MaterialShape.Shape.Cookie4Sided
            case "Cookie6Sided":  return MaterialShape.Shape.Cookie6Sided
            case "Cookie7Sided":  return MaterialShape.Shape.Cookie7Sided
            case "Cookie9Sided":  return MaterialShape.Shape.Cookie9Sided
            case "Cookie12Sided": return MaterialShape.Shape.Cookie12Sided
            case "Ghostish":      return MaterialShape.Shape.Ghostish
            case "Clover4Leaf":   return MaterialShape.Shape.Clover4Leaf
            case "Clover8Leaf":   return MaterialShape.Shape.Clover8Leaf
            case "Burst":         return MaterialShape.Shape.Burst
            case "SoftBurst":     return MaterialShape.Shape.SoftBurst
            case "Boom":          return MaterialShape.Shape.Boom
            case "SoftBoom":      return MaterialShape.Shape.SoftBoom
            case "Flower":        return MaterialShape.Shape.Flower
            case "Puffy":         return MaterialShape.Shape.Puffy
            case "PuffyDiamond":  return MaterialShape.Shape.PuffyDiamond
            case "PixelCircle":   return MaterialShape.Shape.PixelCircle
            case "PixelTriangle": return MaterialShape.Shape.PixelTriangle
            case "Bun":           return MaterialShape.Shape.Bun
            case "Heart":         return MaterialShape.Shape.Heart
            default:              return MaterialShape.Shape.Cookie4Sided
        }
    }

    function centeredShapeMinBoundaryRadius(shape) {
        switch (shape) {
            case MaterialShape.Shape.Circle:        return 0.4898
            case MaterialShape.Shape.Square:        return 0.5000
            case MaterialShape.Shape.Slanted:       return 0.4610
            case MaterialShape.Shape.Arch:          return 0.5000
            case MaterialShape.Shape.Fan:           return 0.3710
            case MaterialShape.Shape.Arrow:         return 0.2992
            case MaterialShape.Shape.SemiCircle:    return 0.3125
            case MaterialShape.Shape.Oval:          return 0.3697
            case MaterialShape.Shape.Pill:          return 0.4157
            case MaterialShape.Shape.Triangle:      return 0.2665
            case MaterialShape.Shape.Diamond:       return 0.3593
            case MaterialShape.Shape.ClamShell:     return 0.3373
            case MaterialShape.Shape.Pentagon:      return 0.3999
            case MaterialShape.Shape.Gem:           return 0.4498
            case MaterialShape.Shape.Sunny:         return 0.4185
            case MaterialShape.Shape.VerySunny:     return 0.3818
            case MaterialShape.Shape.Cookie4Sided:  return 0.3841
            case MaterialShape.Shape.Cookie6Sided:  return 0.4312
            case MaterialShape.Shape.Cookie7Sided:  return 0.4202
            case MaterialShape.Shape.Cookie9Sided:  return 0.4370
            case MaterialShape.Shape.Cookie12Sided: return 0.4463
            case MaterialShape.Shape.Ghostish:      return 0.3637
            case MaterialShape.Shape.Clover4Leaf:   return 0.4019
            case MaterialShape.Shape.Clover8Leaf:   return 0.4287
            case MaterialShape.Shape.Burst:         return 0.3562
            case MaterialShape.Shape.SoftBurst:     return 0.3873
            case MaterialShape.Shape.Boom:          return 0.2175
            case MaterialShape.Shape.SoftBoom:      return 0.2385
            case MaterialShape.Shape.Flower:        return 0.3396
            case MaterialShape.Shape.Puffy:         return 0.3297
            case MaterialShape.Shape.PuffyDiamond:  return 0.3487
            case MaterialShape.Shape.PixelCircle:   return 0.4723
            case MaterialShape.Shape.PixelTriangle: return 0.2352
            case MaterialShape.Shape.Bun:           return 0.2960
            case MaterialShape.Shape.Heart:         return 0.2141
            default:                                return 0.4202
        }
    }
}