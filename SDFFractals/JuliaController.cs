using UnityEngine;
using UnityEngine.UI;

public class JuliaController : MonoBehaviour
{
    Renderer renderer;
    public Slider color1;
    public Slider color2;
    public Slider color3;
    public Slider saturation;

    public Slider RotX;
    public Slider RotY;
    public Slider RotZ;

    public Slider SliceX;
    public Slider SliceY;
    public Slider SliceZ;

    public Slider cameraDistance;

    public Slider iterations;

    void Start()
    {
        renderer = GetComponent<Renderer>();
        renderer.material.shader = Shader.Find("Unlit/JuliaSetLight");

    }

    public void UpdateObject()
    {
        for (int i = 0; i < renderer.materials.Length; i++)
        {
            renderer.materials[i].SetFloat("_ColorR", (float)(color1.value));
            renderer.materials[i].SetFloat("_ColorG", (float)(color2.value));
            renderer.materials[i].SetFloat("_ColorB", (float)(color3.value));
            renderer.materials[i].SetFloat("_Saturation", (float)(saturation.value));
            renderer.materials[i].SetFloat("_RotX", (float)(RotX.value));
            renderer.materials[i].SetFloat("_RotY", (float)(RotY.value));
            renderer.materials[i].SetFloat("_RotZ", (float)(RotZ.value));
            renderer.materials[i].SetFloat("_Iterations", (float)(iterations.value));
        }
    }

    public void UpdateCamera()
    {
        for (int i = 0; i < renderer.materials.Length; i++)
        {
            renderer.materials[i].SetFloat("_CameraDistance", (float)(cameraDistance.value));
        }
    }

    public void UpdateSlices()
    {
        for (int i = 0; i < renderer.materials.Length; i++)
        {
            renderer.materials[i].SetFloat("_SliceX", (float)(SliceX.value));
            renderer.materials[i].SetFloat("_SliceY", (float)(SliceY.value));
            renderer.materials[i].SetFloat("_SliceZ", (float)(SliceZ.value));
        }
    }

}
