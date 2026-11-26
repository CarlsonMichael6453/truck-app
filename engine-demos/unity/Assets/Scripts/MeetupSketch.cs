using UnityEngine;

namespace TruckDemo
{
    /// <summary>
    /// What a two-truck meetup would replicate. The lot scene is the place.
    /// Netcode for GameObjects would host this struct on a NetworkObject:
    /// NetworkVariable position, yaw, paint, and wheel id, with Unity Transport
    /// on a direct socket or Unity Relay. Photon Fusion / PUN is the hosted
    /// alternative and bills by CCU after the free tier. Godot's ENet peer in
    /// the other demo is the same idea without an account.
    /// </summary>
    public struct TruckNetState
    {
        public Vector3 Position;
        public float YawRadians;
        public Color Paint;
        public int Wheel;
        public int Bumper;
    }

    public static class MeetupSketch
    {
        public const int Port = 7777;

        public static TruckNetState Capture(Transform truck, Color paint)
        {
            return new TruckNetState
            {
                Position = truck.position,
                YawRadians = truck.eulerAngles.y * Mathf.Deg2Rad,
                Paint = paint,
            };
        }
    }
}
