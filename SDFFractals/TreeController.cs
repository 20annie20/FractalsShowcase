using UnityEngine.UI;
using UnityEngine;

public class TreeController : MonoBehaviour
{
    Renderer renderer;
    public Slider saturation;
    public Slider precision;
    public Slider branches;

    // Start is called before the first frame update
    void Start()
    {
        renderer = GetComponent<Renderer>();
        renderer.material.shader = Shader.Find("Unlit/Tree");
    }

    public void UpdateObject()
    {
        for (int i = 0; i < renderer.materials.Length; i++)
        {
            renderer.materials[i].SetFloat("_Lightness", (float)(saturation.value));
            renderer.materials[i].SetFloat("_Precyzja", (float)(precision.value));
            renderer.materials[i].SetFloat("_Branches", (float)(branches.value));
        }
    }
}
