using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class NaiveMengerSponge : MonoBehaviour
{
    public GameObject CubePrefab;

    void Start()
    {
        float Size = 8.0f;
        Menger(Size, 2, new Vector3(0, 0, 0));
	}

    private void Update()
    {
		StartCoroutine("Reset");
		float Size = 20.0f;
		Menger(Size, 2, new Vector3(0, 0, 0));
	}

	IEnumerator Reset()
	{
		// your process
		yield return new WaitForSeconds(5);
		// continue process
	}

	void Menger(float Size, int Iterations, Vector3 CubeSP)
	{
		Debug.Log("Iterations");
		Debug.Log(Iterations);
		Debug.Log(Size);

		if (Iterations > 0)
		{
			float DistanceToAdd = Size / 3;

			int[] IndicesToSkip = { 4, 10, 12, 13, 14, 16, 22 };
			List<Vector3> _positions = new List<Vector3>();

			for (int z = 0; z < 3; z++)
			{
				for (int y = 0; y < 3; y++)
				{
					for (int x = 0; x < 3; x++)
					{
						int Index1D = x + y * 3 + z * 9;
						if (!IndicesToSkip.Contains(Index1D))
						{
							Vector3 _position = new Vector3(CubeSP.x + x * DistanceToAdd, CubeSP.y + y * DistanceToAdd, CubeSP.z + z * DistanceToAdd); //pewnie da się bardziej elegancko
							_positions.Add(_position);
						}
					}
				}
			}

			foreach ( Vector3 NewCubeSP in _positions)
			{
				Menger(Size / 3.0f, Iterations - 1, NewCubeSP);
			}
		}

		else
		{
			GameObject obj = Instantiate(CubePrefab, CubeSP, Quaternion.identity);
			obj.GetComponent<Renderer>().material.color = Random.ColorHSV(0f, 1f, 1f, 1f, 0.5f, 1f);
			return;
		}
	}

}
