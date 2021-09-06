using System.Collections.Generic;
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

    [Range(0f, 100f), Tooltip("Glossiness of the liquid")]
    public ClampedFloatParameter glossiness = new ClampedFloatParameter(50f, 0f, 100f);

    [Range(0f, 1f), Tooltip("Metallicness of the liquid")]
    public ClampedFloatParameter metallic = new ClampedFloatParameter(0f, 0f, 1f);

    [Range(0f, 1f), Tooltip("Smoothness of the liquid")]
    public ClampedFloatParameter smoothness = new ClampedFloatParameter(0f, 0f, 1f);

    [Range(0f, 2f), Tooltip("Smoothness between spheres")]
    public ClampedFloatParameter sphereSmooth = new ClampedFloatParameter(1.5f, 0f, 2f);
}

// Define the renderer for the custom post processing effect
[CustomPostProcess("Liquid", CustomPostProcessInjectionPoint.BeforePostProcess)]
public class LiquidEffectRenderer : CustomPostProcessRenderer
{
    // A variable to hold a reference to the corresponding volume component
    private LiquidEffect m_VolumeComponent;

    // The postprocessing material
    private Material m_Material;
    private Camera cam;

    //Spheres
    int nbActiveSphere;
    private Texture2D spheresData;


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
        internal readonly static int SpheresData = Shader.PropertyToID("_spheresData");
        internal readonly static int NbSphere = Shader.PropertyToID("_nbSphere");
        internal readonly static int PoolSize = Shader.PropertyToID("_poolSize");
        internal readonly static int SphereSmooth = Shader.PropertyToID("_sphereSmooth");

        //Lighting
        internal readonly static int Glossiness = Shader.PropertyToID("_glossiness");
        internal readonly static int Metallic = Shader.PropertyToID("_metallic");
        internal readonly static int Smoothness = Shader.PropertyToID("_smoothness");
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
            //Spheres
            if(spheresData == null && LiquidPoolManager.Instance.poolSize != 0)
            {
                //Init spheres
                spheresData = new Texture2D(LiquidPoolManager.Instance.poolSize, 1, TextureFormat.RGBAFloat, false);
                spheresData.filterMode = FilterMode.Point;
                spheresData.wrapMode = TextureWrapMode.Clamp;
            }

            //Set spheres position and scale into the texture
            for (int i = 0; i < LiquidPoolManager.Instance.activeSpheres.Count; i++)
            {
                Vector3 pos = LiquidPoolManager.Instance.activeSpheres[i].position;
                spheresData.SetPixel(i, 0, new Color(pos.x * 0.001f, pos.y * 0.001f, pos.z * 0.001f, LiquidPoolManager.Instance.activeSpheres[i].localScale.x * 0.001f));
            }
            spheresData.Apply();

            m_Material.SetFloat(ShaderIDs.Intensity, m_VolumeComponent.intensity.value);
            m_Material.SetMatrix(ShaderIDs.CamInvProj, cam.projectionMatrix.inverse);
            m_Material.SetFloat(ShaderIDs.MaxDistance, m_VolumeComponent.maxDistance.value);
            m_Material.SetInt(ShaderIDs.MaxIterations, m_VolumeComponent.maxIterations.value);
            m_Material.SetFloat(ShaderIDs.Accuracy, m_VolumeComponent.accuracy.value);

            //Send spheres data to the shader
            m_Material.SetTexture(ShaderIDs.SpheresData, spheresData);
            m_Material.SetInt(ShaderIDs.NbSphere, LiquidPoolManager.Instance.activeSpheres.Count);
            m_Material.SetInt(ShaderIDs.PoolSize, LiquidPoolManager.Instance.poolSize);
            m_Material.SetFloat(ShaderIDs.SphereSmooth, m_VolumeComponent.sphereSmooth.value);

            //Lighting
            m_Material.SetFloat(ShaderIDs.Glossiness, m_VolumeComponent.glossiness.value);
            m_Material.SetFloat(ShaderIDs.Metallic, m_VolumeComponent.metallic.value);
            m_Material.SetFloat(ShaderIDs.Smoothness, m_VolumeComponent.smoothness.value);

        }
        // set source texture
        cmd.SetGlobalTexture(ShaderIDs.Input, source);
        // draw a fullscreen triangle to the destination
        CoreUtils.DrawFullScreen(cmd, m_Material, destination);
    }
}