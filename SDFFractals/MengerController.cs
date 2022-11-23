using UnityEngine;
using UnityEngine.UI;

public class MengerController : MonoBehaviour
{
    Renderer renderer;
    public Slider color1;
    public Slider color2;
    public Slider color3;
    public Slider saturation;

    public Slider SliceX;
    public Slider SliceY;
    public Slider SliceZ;

    public Slider cameraDistance;

    public Slider shape;
    public Slider size;

    void Start()
    {
        renderer = GetComponent<Renderer>();
        renderer.material.shader = Shader.Find("Unlit/MengerSponge");
        
    }

    public void UpdateObject()
    {
        for (int i = 0; i < renderer.materials.Length; i++)
        {
            renderer.materials[i].SetFloat("_CubeColor1", (float)(color1.value * 20.0));
            renderer.materials[i].SetFloat("_CubeColor2", (float)(color2.value * 20.0));
            renderer.materials[i].SetFloat("_CubeColor3", (float)(color3.value * 20.0));
            renderer.materials[i].SetFloat("_CubeSaturation", (float)(saturation.value));
            renderer.materials[i].SetFloat("_SizeX", (float)(size.value));
            renderer.materials[i].SetFloat("_Ksztalt", (float)(shape.value));
        }
    }

    public void UpdateCamera()
    {
        for (int i = 0; i < renderer.materials.Length; i++)
        {
            renderer.materials[i].SetFloat("_CameraDist", (float)(cameraDistance.value));
        }
    }

    public void UpdateSlices ()
    {
        for (int i = 0; i < renderer.materials.Length; i++)
        {
            renderer.materials[i].SetFloat("_SliceX", (float)(SliceX.value));
            renderer.materials[i].SetFloat("_SliceY", (float)(SliceY.value));
            renderer.materials[i].SetFloat("_SliceZ", (float)(SliceZ.value));
        }
    }

}
