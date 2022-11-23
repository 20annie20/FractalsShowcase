using UnityEngine.UI;
using UnityEngine;

public class SierpinskiController : MonoBehaviour
{
    Renderer renderer;
    public Slider iterations;
    public Slider speed;
    public Slider filling;

    void Start()
    {
        renderer = GetComponent<Renderer>();
        renderer.material.shader = Shader.Find("Unlit/sierpinski");
    }

    public void UpdateObject()
    {
        for (int i = 0; i < renderer.materials.Length; i++)
        {
            renderer.materials[i].SetFloat("_Iterations", (float)(iterations.value));
            renderer.materials[i].SetFloat("_Speed", (float)(speed.value));
            renderer.materials[i].SetFloat("_Filling", (float)(filling.value));
        }
    }
}
