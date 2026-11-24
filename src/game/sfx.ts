let audio: AudioContext | null = null

export function playTone(enabled: boolean, frequency: number, duration = 0.07, gain = 0.035) {
  if (!enabled || typeof AudioContext === "undefined") return
  try {
    audio ??= new AudioContext()
    const osc = audio.createOscillator()
    const amp = audio.createGain()
    osc.type = "triangle"
    osc.frequency.value = frequency
    amp.gain.value = gain
    amp.gain.exponentialRampToValueAtTime(0.0001, audio.currentTime + duration)
    osc.connect(amp)
    amp.connect(audio.destination)
    osc.start()
    osc.stop(audio.currentTime + duration)
  } catch {
    audio = null
  }
}
