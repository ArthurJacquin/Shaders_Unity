using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.PostProcessing;

// Define the Volume Component for the custom post processing effect 
[System.Serializable, VolumeComponentMenu("CustomPostProcess/Raymarching/Liquid")]
public class LiquidEffect : VolumeComponent
{
    [Range(0, 1), Tooltip("Effect intensity")]
    public ClampedFloatParameter intensity = new ClampedFloatParameter(1, 0, 1);

    [Range(1, 300), Tooltip("Max distance of the raymarching")]
    public ClampedFloatParameter maxDistance = new ClampedFloatParameter(300, 0, 500);

    [Range(1, 500), Tooltip("Max iteration of the raymarching")]
    public ClampedIntParameter maxIterations = new ClampedIntParameter(500, 0, 500);

    [Range(0.0001f, 0.01f), Tooltip("Accuracy of the raymarching")]
    public ClampedFloatParameter accuracy = new ClampedFloatParameter(0.001f, 0.0001f, 0.01f);

    [Range(0f, 4f), Tooltip("Intensity of the shadows cast by raymarched objects")]
    public ClampedFloatParameter shadowIntensity = new ClampedFloatParameter(1, 0f, 4f);

    [Tooltip("Shadow propagation")]
    public Vector2Parameter shadowDistance = new Vector2Parameter(new Vector2(0.5f, 50f));

    [Range(1f, 10f), Tooltip("Intensity of the shadows cast by raymarched objects")]
    public ClampedFloatParameter shadowPenumbra = new ClampedFloatParameter(4.5f, 1f, 10f);

    [Range(0f, 100f), Tooltip("Glossiness of the liquid")]
    public ClampedFloatParameter glossiness = new ClampedFloatParameter(50f, 0f, 100f);
}

// Define the renderer for the custom post processing effect
[CustomPostProcess("Liquid", CustomPostProcessInjectionPoint.AfterPostProcess)]
public class LiquidEffectRenderer : CustomPostProcessRenderer
{
    // A variable to hold a reference to the corresponding volume component
    private LiquidEffect m_VolumeComponent;

    // The postprocessing material
    private Material m_Material;
    private Camera cam;
    private Transform sphere;

    // The ids of the shader variables
    static class ShaderIDs
    {
        internal readonly static int Input = Shader.PropertyToID("_MainTex");
        internal readonly static int Intensity = Shader.PropertyToID("_Intensity");
        internal readonly static int CamInvProj = Shader.PropertyToID("_CamInvProj");
        internal readonly static int MaxDistance = Shader.PropertyToID("_maxDistance");
        internal readonly static int MaxIterations = Shader.PropertyToID("_maxIterations");
        internal readonly static int Accuracy = Shader.PropertyToID("_accuracy");

        //Shperes
        internal readonly static int Pos = Shader.PropertyToID("pos");

        //Shadows
        internal readonly static int ShadowIntensity = Shader.PropertyToID("_shadowIntensity");
        internal readonly static int ShadowDistance = Shader.PropertyToID("_shadowDistance");
        internal readonly static int ShadowPenumbra = Shader.PropertyToID("_shadowPenumbra");

        //Lighting
        internal readonly static int Glossiness = Shader.PropertyToID("_glossiness");
    }

    // By default, the effect is visible in the scene view, but we can change that here.
    public override bool visibleInSceneView => true;

    /// Specifies the input needed by this custom post process. Default is Color only.
    public override ScriptableRenderPassInput input => ScriptableRenderPassInput.Color;

    // Initialized is called only once before the first render call
    // so we use it to create our material
    public override void Initialize()
    {
        m_Material = CoreUtils.CreateEngineMaterial("Hidden/Raymarching/Liquid");
        cam = Camera.main;
        sphere = cam.transform.GetChild(0);
    }

    // Called for each camera/injection point pair on each frame. Return true if the effect should be rendered for this camera.
    public override bool Setup(ref RenderingData renderingData, CustomPostProcessInjectionPoint injectionPoint)
    {
        // Get the current volume stack
        var stack = VolumeManager.instance.stack;
        // Get the corresponding volume component
        m_VolumeComponent = stack.GetComponent<LiquidEffect>();
        // if intensity value > 0, then we need to render this effect. 
        return m_VolumeComponent.intensity.value > 0;
    }

    // The actual rendering execution is done here
    public override void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier destination, ref RenderingData renderingData, CustomPostProcessInjectionPoint injectionPoint)
    {
        // set material properties
        if (m_Material != null)
        {
            m_Material.SetFloat(ShaderIDs.Intensity, m_VolumeComponent.intensity.value);
            m_Material.SetMatrix(ShaderIDs.CamInvProj, cam.projectionMatrix.inverse);
            m_Material.SetFloat(ShaderIDs.MaxDistance, m_VolumeComponent.maxDistance.value);
            m_Material.SetInt(ShaderIDs.MaxIterations, m_VolumeComponent.maxIterations.value);
            m_Material.SetFloat(ShaderIDs.Accuracy, m_VolumeComponent.accuracy.value);

            //Spheres
            m_Material.SetVector(ShaderIDs.Pos, sphere.position);

            //Shadows
            m_Material.SetFloat(ShaderIDs.ShadowIntensity, m_VolumeComponent.shadowIntensity.value);
            m_Material.SetVector(ShaderIDs.ShadowDistance, m_VolumeComponent.shadowDistance.value);
            m_Material.SetFloat(ShaderIDs.ShadowPenumbra, m_VolumeComponent.shadowPenumbra.value);

            //Lighting
            m_Material.SetFloat(ShaderIDs.Glossiness, m_VolumeComponent.glossiness.value);

        }
        // set source texture
        cmd.SetGlobalTexture(ShaderIDs.Input, source);
        // draw a fullscreen triangle to the destination
        CoreUtils.DrawFullScreen(cmd, m_Material, destination);
    }

    /// \brief Stores the normalized rays representing the camera frustum in a 4x4 matrix.  Each row is a vector.
    /// 
    /// The following rays are stored in each row (in eyespace, not worldspace):
    /// Top Left corner:     row=0
    /// Top Right corner:    row=1
    /// Bottom Right corner: row=2
    /// Bottom Left corner:  row=3
    private Matrix4x4 GetFrustumCorners(Camera cam)
    {
        float camAspect = cam.aspect;

        Matrix4x4 frustumCorners = Matrix4x4.identity;

        float fov = Mathf.Tan((cam.fieldOfView * 0.5f) * Mathf.Deg2Rad);

        Vector3 toRight = Vector3.right * fov * camAspect;
        Vector3 toTop = Vector3.up * fov;

        Vector3 topLeft = (-Vector3.forward - toRight + toTop);
        Vector3 topRight = (-Vector3.forward + toRight + toTop);
        Vector3 bottomRight = (-Vector3.forward + toRight - toTop);
        Vector3 bottomLeft = (-Vector3.forward - toRight - toTop);

        frustumCorners.SetRow(0, topLeft);
        frustumCorners.SetRow(1, topRight);
        frustumCorners.SetRow(2, bottomRight);
        frustumCorners.SetRow(3, bottomLeft);

        return frustumCorners;
    }
}