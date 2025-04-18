#Include CLR.ahk

; Static class, holds ViGEm Client instance
class ViGEmWrapper {
    static asm := 0
    static client := 0
    
    static Init() {
        if (this.client == 0) {
            this.asm := CLR_LoadLibrary(A_LineFile "\..\ViGEmWrapper.dll")
        }
    }
    
    static CreateInstance(cls) {
        return this.asm.CreateInstance(cls)
    }
}

; Base class for ViGEm "Targets" (Controller types - eg xb360 / ds4) to inherit from
class ViGEmTarget {
    target := 0
    helperClass := ""
    controllerClass := ""

    __New() {
        ViGEmWrapper.Init()
        this.Instance := ViGEmWrapper.CreateInstance(this.helperClass)
        
        if (this.Instance.OkCheck() != "OK") {
            MsgBox "ViGEmWrapper.dll failed to load!"
            ExitApp
        }
    }
    
    SendReport() {
        this.Instance.SendReport()
    }
    
    SubscribeFeedback(callback) {
        this.Instance.SubscribeFeedback(callback)
    }
}

; DS4 (DualShock 4 for Playstation 4)
class ViGEmDS4 extends ViGEmTarget {
    helperClass := "ViGEmWrapper.Ds4"
    __New() {
        static buttons := Map(
            "Square", 16, "Cross", 32, "Circle", 64, "Triangle", 128,
            "L1", 256, "R1", 512, "L2", 1024, "R2", 2048,
            "Share", 4096, "Options", 8192, "LS", 16384, "RS", 32768
        )
        static specialButtons := Map("Ps", 1, "TouchPad", 2)
        static axes := Map("LX", 2, "LY", 3, "RX", 4, "RY", 5, "LT", 0, "RT", 1)
        
        this.Buttons := Map()
        for name, id in buttons {
            this.Buttons[name] := ViGEmDS4._ButtonHelper(this, id)
        }
        for name, id in specialButtons {
            this.Buttons[name] := ViGEmDS4._SpecialButtonHelper(this, id)
        }
        
        this.Axes := Map()
        for name, id in axes {
            this.Axes[name] := ViGEmDS4._AxisHelper(this, id)
        }
        
        this.Dpad := ViGEmDS4._DpadHelper(this)
        super.__New()
    }
    
    class _ButtonHelper {
        __New(parent, id) {
            this._Parent := parent
            this._Id := id
        }
        
        SetState(state) {
            this._Parent.Instance.SetButtonState(this._Id, state)
            this._Parent.Instance.SendReport()
            return this._Parent
        }
    }
    
    class _SpecialButtonHelper {
        __New(parent, id) {
            this._Parent := parent
            this._Id := id
        }
        
        SetState(state) {
            this._Parent.Instance.SetSpecialButtonState(this._Id, state)
            this._Parent.Instance.SendReport()
            return this._Parent
        }
    }
    
    class _AxisHelper {
        __New(parent, id) {
            this._Parent := parent
            this._Id := id
        }
        
        SetState(state) {
            this._Parent.Instance.SetAxisState(this._Id, this.ConvertAxis(state))
            this._Parent.Instance.SendReport()
            return this._Parent
        }
        
        ConvertAxis(state) {
            return Round(state * 2.55)
        }
    }
    
    class _DpadHelper {
        __New(parent, id) {
            this._Parent := parent
            this._Id := id
        }
        
        SetState(state) {
            static dPadDirections := Map(
                "Up", 0, "UpRight", 1, "Right", 2, "DownRight", 3,
                "Down", 4, "DownLeft", 5, "Left", 6, "UpLeft", 7, "None", 8
            )
            this._Parent.Instance.SetDpadState(dPadDirections[state])
            this._Parent.Instance.SendReport()
            return this._Parent
        }
    }
}

; Xb360
; Xb360
class ViGEmXb360 extends ViGEmTarget {
    helperClass := "ViGEmWrapper.Xb360"
    __New() {
        static buttons := Map(
            "A", 4096, "B", 8192, "X", 16384, "Y", 32768,
            "LB", 256, "RB", 512, "LS", 64, "RS", 128,
            "Back", 32, "Start", 16, "Xbox", 1024
        )
        static axes := Map("LX", 2, "LY", 3, "RX", 4, "RY", 5, "LT", 0, "RT", 1)
        
        this.Buttons := Map()
        for name, id in buttons {
            this.Buttons[name] := ViGEmXb360._ButtonHelper(this, id)
        }
        
        this.Axes := Map()
        for name, id in axes {
            this.Axes[name] := ViGEmXb360._AxisHelper(this, id)
        }
        
        this.Dpad := ViGEmXb360._DpadHelper(this)
        
        super.__New()
    }
    
    class _ButtonHelper {
        __New(parent, id) {
            this._Parent := parent
            this._Id := id
        }
        
        SetState(state) {
            this._Parent.Instance.SetButtonState(this._Id, state)
            this._Parent.Instance.SendReport()
            return this._Parent
        }
    }
    
    class _AxisHelper {
        __New(parent, id) {
            this._Parent := parent
            this._id := id
        }
        
        SetState(state) {
            this._Parent.Instance.SetAxisState(this._Id, this.ConvertAxis(state))
            this._Parent.Instance.SendReport()
        }
        
        ConvertAxis(state) {
            value := Round((state * 655.36) - 32768)
            if (value == 32768)
                return 32767
            return value
        }
    }
    
    class _DpadHelper {
        _DpadStates := Map(1, 0, 8, 0, 2, 0, 4, 0) ; Up, Right, Down, Left
        __New(parent) {
            this._Parent := parent
        }
        
        SetState(state) {
            static dpadDirections := Map(
                "None", Map(1, 0, 8, 0, 2, 0, 4, 0),
                "Up", Map(1, 1, 8, 0, 2, 0, 4, 0),
                "UpRight", Map(1, 1, 8, 1, 2, 0, 4, 0),
                "Right", Map(1, 0, 8, 1, 2, 0, 4, 0),
                "DownRight", Map(1, 0, 8, 1, 2, 1, 4, 0),
                "Down", Map(1, 0, 8, 0, 2, 1, 4, 0),
                "DownLeft", Map(1, 0, 8, 0, 2, 1, 4, 1),
                "Left", Map(1, 0, 8, 0, 2, 0, 4, 1),
                "UpLeft", Map(1, 1, 8, 0, 2, 0, 4, 1)
            )
            newStates := dpadDirections[state]
            for id, newState in newStates {
                oldState := this._DpadStates[id]
                if (oldState != newState) {
                    this._DpadStates[id] := newState
                    this._Parent.Instance.SetButtonState(id, newState)
                }
                this._Parent.SendReport()
            }
        }
    }
}