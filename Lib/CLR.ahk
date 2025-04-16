; ==========================================================
;                  .NET Framework Interop
;      https://autohotkey.com/boards/viewtopic.php?t=4633
; ==========================================================
;
;   Author:     Lexikos
;   Version:    1.2
;   Updated:    Converted to AHK v2
;

CLR_LoadLibrary(AssemblyName, AppDomain := 0)
{
    if !AppDomain
        AppDomain := CLR_GetDefaultDomain()
    e := ComObjError(0)
    Loop 1 {
        if assembly := AppDomain.Load_2(AssemblyName)
            break
        static null := ComObject(13, 0)
        args := ComObjArray(0xC, 1), args[0] := AssemblyName
        typeofAssembly := AppDomain.GetType().Assembly.GetType()
        if assembly := typeofAssembly.InvokeMember_3("LoadWithPartialName", 0x158, null, null, args)
            break
        if assembly := typeofAssembly.InvokeMember_3("LoadFrom", 0x158, null, null, args)
            break
    }
    ComObjError(e)
    return assembly
}

CLR_CreateObject(Assembly, TypeName, Args*)
{
    if !(argCount := Args.Length)
        return Assembly.CreateInstance_2(TypeName, true)
    
    vargs := ComObjArray(0xC, argCount)
    for i, arg in Args
        vargs[i-1] := arg
    
    static Array_Empty := ComObjArray(0xC, 0), null := ComObject(13, 0)
    
    return Assembly.CreateInstance_3(TypeName, true, 0, null, vargs, null, Array_Empty)
}

CLR_CompileC#(Code, References := "", AppDomain := 0, FileName := "", CompilerOptions := "")
{
    return CLR_CompileAssembly(Code, References, "System", "Microsoft.CSharp.CSharpCodeProvider", AppDomain, FileName, CompilerOptions)
}

CLR_CompileVB(Code, References := "", AppDomain := 0, FileName := "", CompilerOptions := "")
{
    return CLR_CompileAssembly(Code, References, "System", "Microsoft.VisualBasic.VBCodeProvider", AppDomain, FileName, CompilerOptions)
}

CLR_StartDomain(&AppDomain, BaseDirectory := "")
{
    static null := ComObject(13, 0)
    args := ComObjArray(0xC, 5), args[0] := "", args[2] := BaseDirectory, args[4] := ComObject(0xB, false)
    AppDomain := CLR_GetDefaultDomain().GetType().InvokeMember_3("CreateDomain", 0x158, null, null, args)
    return A_LastError >= 0
}

CLR_StopDomain(&AppDomain)
{   ; ICorRuntimeHost::UnloadDomain
    DllCall("SetLastError", "uint", hr := DllCall(NumGet(NumGet(0+RtHst:=CLR_Start())+20*A_PtrSize), "ptr", RtHst, "ptr", ComObjValue(AppDomain))), AppDomain := ""
    return hr >= 0
}

; NOTE: IT IS NOT NECESSARY TO CALL THIS FUNCTION unless you need to load a specific version.
CLR_Start(Version := "") ; returns ICorRuntimeHost*
{
    static RtHst := 0
    if RtHst
        return RtHst
    SystemRoot := EnvGet("SystemRoot")
    if Version == ""
        Loop Files SystemRoot "\Microsoft.NET\Framework" (A_PtrSize=8?"64":"") "\*", "D"
            if (FileExist(A_LoopFileFullPath "\mscorlib.dll") && A_LoopFileName > Version)
                Version := A_LoopFileName
    if DllCall("mscoree\CorBindToRuntimeEx", "wstr", Version, "ptr", 0, "uint", 0
    , "ptr", CLR_GUID(CLSID_CorRuntimeHost, "{CB2F6723-AB3A-11D2-9C40-00C04FA30A3E}")
    , "ptr", CLR_GUID(IID_ICorRuntimeHost,  "{CB2F6722-AB3A-11D2-9C40-00C04FA30A3E}")
    , "ptr*", &RtHst) >= 0
        DllCall(NumGet(NumGet(RtHst+0)+10*A_PtrSize), "ptr", RtHst) ; Start
    return RtHst
}

;
; INTERNAL FUNCTIONS
;

CLR_GetDefaultDomain()
{
    static defaultDomain := 0
    if !defaultDomain
    {   ; ICorRuntimeHost::GetDefaultDomain
        if DllCall(NumGet(NumGet(0+RtHst:=CLR_Start())+13*A_PtrSize), "ptr", RtHst, "ptr*", &p:=0) >= 0
            defaultDomain := ComObject(p), ObjRelease(p)
    }
    return defaultDomain
}

CLR_CompileAssembly(Code, References, ProviderAssembly, ProviderType, AppDomain := 0, FileName := "", CompilerOptions := "")
{
    if !AppDomain
        AppDomain := CLR_GetDefaultDomain()
    
    if !(asmProvider := CLR_LoadLibrary(ProviderAssembly, AppDomain))
    || !(codeProvider := asmProvider.CreateInstance(ProviderType))
    || !(codeCompiler := codeProvider.CreateCompiler())
        return 0

    if !(asmSystem := (ProviderAssembly="System") ? asmProvider : CLR_LoadLibrary("System", AppDomain))
        return 0
    
    ; Convert | delimited list of references into an array.
    Refs := StrSplit(References, "|", " `t")
    aRefs := ComObjArray(8, Refs.Length)
    for i, ref in Refs
        aRefs[i-1] := ref
    
    ; Set parameters for compiler.
    prms := CLR_CreateObject(asmSystem, "System.CodeDom.Compiler.CompilerParameters", aRefs)
    prms.OutputAssembly          := FileName
    prms.GenerateInMemory        := FileName==""
    prms.GenerateExecutable      := SubStr(FileName, -3)==".exe"
    prms.CompilerOptions         := CompilerOptions
    prms.IncludeDebugInformation := true
    
    ; Compile!
    compilerRes := codeCompiler.CompileAssemblyFromSource(prms, Code)
    
    if error_count := (errors := compilerRes.Errors).Count
    {
        error_text := ""
        Loop error_count
        {
            e := errors.Item[A_Index-1]
            error_text .= ((e.IsWarning) ? "Warning " : "Error ") . e.ErrorNumber " on line " e.Line ": " e.ErrorText "`n`n"
        }
        MsgBox "Compilation Failed", error_text, 16
        return 0
    }
    ; Success. Return Assembly object or path.
    return compilerRes[FileName=="" ? "CompiledAssembly" : "PathToAssembly"]
}

CLR_GUID(&GUID, sGUID)
{
    GUID := Buffer(16, 0)
    return DllCall("ole32\CLSIDFromString", "wstr", sGUID, "ptr", GUID) >= 0 ? GUID.Ptr : ""
}