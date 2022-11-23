using UnityEngine.UI;
using UnityEngine;

public class MandelbulbController : MonoBehaviour
{
    Renderer renderer;
    public Slider cameraDistance;
    public Slider rotation;
    public Slider power;
    public Slider radius;
    public Slider iterations;

    public Slider saturation;
    public Slider brightness;
    public Slider contrast;

    void Start()
    {
        renderer = GetComponent<Renderer>();
        renderer.material.shader = Shader.Find("Unlit/Mandelbulb");
    }

    public void UpdateObject()
    {
        for (int i = 0; i < renderer.materials.Length; i++)
        {
            renderer.materials[i].SetFloat("_CameraDistance", (float)(cameraDistance.value));
            renderer.materials[i].SetFloat("_RotX", (float)(rotation.value));
            renderer.materials[i].SetFloat("_MandelbulbPower", (float)(power.value));
            renderer.materials[i].SetFloat("_ViewRadius", (float)(radius.value));
            renderer.materials[i].SetFloat("_Iterations", (float)(iterations.value));
            renderer.materials[i].SetFloat("_Saturation", (float)(saturation.value));
            renderer.materials[i].SetFloat("_Brightness", (float)(brightness.value));
            renderer.materials[i].SetFloat("_Contrast", (float)(contrast.value));
        }
    }
}
