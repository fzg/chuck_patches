/*
	TODO:
		note handler
		envelope
		rewrite native ugen
			-> mixer is not split into two ugens yet. should it?
    Members:
      master osc: m
      other oscs: o[6]
*/



class Supersaw
{
 Mix    ss_mix;  // six channel mixer [todo, curves]
 Detune ss_det;  // detuner
 Gain master_g;  // master osc gain
 Gain other_g;   // other oscs gain
 HPF ss_hpf;     // high pass filter

  // connect mixer output to gain nodes (fixme: has to be done each tick)
  // ss_mix.main()  => float f0 => master_g.gain;
  // ss_mix.other() => float f1 => other_g.gain;

  // connect detuner to osc to gain nodes
  SawOsc m => master_g;
  SawOsc o0 => other_g;
  SawOsc o1 => other_g;
  SawOsc o2 => other_g;
  SawOsc o3 => other_g;
  SawOsc o4 => other_g;
  SawOsc o5 => other_g;
  Echo rev;
   // insert HPF
   master_g => ss_hpf;
   other_g => ss_hpf;
   ss_hpf => dac;

  fun void meep(float f) {
    f =>  ss_det.freq;
    f => ss_hpf.freq;

    Std.rand2f(0,1) => ss_det.det;
    Std.rand2f(0,1) => ss_mix.mix;

    Std.rand2f(0,1) => m.phase;
    Std.rand2f(0,1) => o0.phase;
    Std.rand2f(0,1) => o1.phase;
    Std.rand2f(0,1) => o2.phase;
    Std.rand2f(0,1) => o3.phase;
    Std.rand2f(0,1) => o4.phase;
    Std.rand2f(0,1) => o5.phase;


    ss_det.d0() => float ff0 => o0.freq;
    ss_det.d1() => float ff1 => o1.freq;
    ss_det.d2() => float ff2 => o2.freq;
    ss_det.d3() => float ff3 => o3.freq;
    ss_det.d4() => float ff4 => o4.freq;
    ss_det.d5() => float ff5 => o5.freq;

    ss_mix.main()  => float f0 => master_g.gain;
    ss_mix.other() => float f1 => other_g.gain;

//    master_g => ss_hpf;
//    other_g => ss_hpf;
    ss_hpf => rev => dac;
    230::ms => now;
    ss_hpf =< rev;
    250::ms => now;
    rev =< dac;
  }
}

Supersaw s;// => dac;

fun void sound() {
  for (440 => float f; f < 800;) {
    f + 100. => f;
    800::ms => now;
 
    <<< s.meep(f) >>>;
//     230::ms => now;
     <<< "Playing freq ", f >>>;
     Math.fmod(f + Std.rand2f(0, 99), 40) => f;
  }
}

while (1) {
  sound();
}
