// supersaw
// based on study by Adam Szabo
// https://www.nada.kth.se/utbildning/grukth/exjobb/rapportlistor/2010/rapporter10/szabo_adam_10131.pdf

// TODO:
//  handle midi messages
//  
// CONTROLS:
//  [left - right] => detune amount
//  [ up  - down ] => oscs mix

class supersaw {
   static Gain   @c[6];  // six channel mixer [todo, curves]
   static SawOsc @o[6];  // six sawtooth oscs
   static HPF    @f[6];  // six hpfs
   new Gain[6]   @=> c;
   new HPF[6]    @=> f;
   new SawOsc[6] @=> o;
   Detune xd;
   ADSR env;
   float mixcontrol, detunecontrol, mfreq;
 
   0.5 => detunecontrol => xd.amount;		// initial amount of detuning
   0.5 => mixcontrol;		// initial oscillator mixing
   for(0 =>int i; i < 6; ++i) {
     o[i] => f[i] => c[i] => dac;//env => dac;
     setMixLevel(i);
   }

   // computes the detuned frequency for each osc
   [ - 0.11002313,  - 0.06288439,- 0.01952356, 0.01991221,0.06216538,0.10745242] @=> float osc_offsets[];
   fun float dodetune(float x, int n) {
     if (n == 0)return x;
     //<<<  xd.output() >>>;
     return x+(osc_offsets[n-1] * 1 + xd.output());
   }

   // returns a random phase
   fun float randphase() {
     return Std.rand2f(-Math.PI / 2.0, Math.PI / 2.0);
   }

   // Mixes: main osc gain decreases linearly, 6 others' increase parabolically
   fun void setMixLevel(int i) {
     if (i == 0) -0.55366*mixcontrol + 0.99785 => c[i].gain;
     else -0.73764*mixcontrol*mixcontrol + 1.2841*mixcontrol + 0.044372 => c[i].gain;
   }

   fun void onDetune() {
     for(0 =>int i; i < 6; ++i) {
       dodetune(mfreq,i) => o[i].freq;
       o[i].freq() => float tmp;
       tmp * 2 => f[i].freq;               // adjust HPF
     }

   }

   fun void trigger(float freq) {
     1 => env.keyOn;
     env.set(.1::second,1::second,0.0,.1::second);
     freq => mfreq;
     for(0 =>int i; i < 6; ++i) {
       randphase()   => o[i].phase;
       dodetune(freq,i) => o[i].freq;
       freq * 2 => f[i].freq;               // adjust HPF
     }
   }

   fun void setMixLevels() {
     for(0 =>int i; i < 6; ++i) {
       setMixLevel(i);
     }
   }
}

// ------------------- Polypoly -------------------


public class supersaws {
   16 => int nosc;
   supersaw @s[nosc];
   new supersaw[nosc]    @=> s;

   fun void trigger(float f) {
     for(0=>int i; i<nosc;++i) {
      s[i].trigger(f);
     }
   }
}


// ------------------- RUN LOOP -------------------
// TODO: use midi for keys
//  see examples/midi/polyfony.ck

supersaw s;
KBHit kb;

fun void doCmdKey(int o) {
  kb.getchar();                 // we eat up the 91
  kb.getchar() => int c;

  if (o == 59) { // shift + arrow
    if (c == 65) {       // up arrow
      for(0 =>int i; i < 6; ++i) {
       s.o[i] => s.f[i] => s.c[i] => dac;//env => dac;
       s.setMixLevel(i);
      }
    } else if (c == 66) {       // down arrow
      for(0 =>int i; i < 6; ++i) {
       s.o[i] =< s.f[i] =< s.c[i] =< dac;//env => dac;
       s.setMixLevel(i);
      }
    }

  }
   <<< "[mix]", s.mixcontrol, "[det]", s.detunecontrol >>>;
  if (c == 65 || c == 66) {
    if (c == 66) {		// up arrow
      .025 +=> s.mixcontrol;
      if (s.mixcontrol > 1) 1 => s.mixcontrol;
      s.setMixLevels();
    } else if (c == 65) {	// down arrow
      -.025 +=> s.mixcontrol;
      if (s.mixcontrol < 0) 0 => s.mixcontrol;
      s.setMixLevels();
    }
  } else if (c == 67 || c == 68) {
    if (c == 68) {	// left arrow
      -.025 +=> s.detunecontrol;
    } else if (c == 67) {	// right arrow
      .025 +=> s.detunecontrol;
    }
    if (s.detunecontrol < 0) 0 => s.detunecontrol;
    if (s.detunecontrol >1) 1 => s.detunecontrol;
    s.detunecontrol => s.xd.amount;
    s.onDetune();
  }
}

while( true ) {
    kb => now;		// wait on kbd event

    while( kb.more() ) {
        kb.getchar() => int c;
 <<< c >>>;
        if (c == 27 || c == 59) {	// '^'
          doCmdKey(c);
        } else {
          c => Std.mtof => float f;
          s.trigger(f);
        }
    }
//    24::ms => now;
}
