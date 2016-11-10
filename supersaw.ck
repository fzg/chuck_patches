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
       freq  => f[i].freq;               // adjust HPF
     }
   }

   fun void setMixLevels() {
     for(0 =>int i; i < 6; ++i) {
       setMixLevel(i);
     }
   }

 fun void doCmdKey(int oo, int cc) {

  if (oo == 59) { // shift + arrow
    if (cc == 65) {       // up arrow
      for(0 =>int i; i < 6; ++i) {
       o[i] => f[i] => c[i] => dac;//env => dac;
       setMixLevel(i);
      }
    } else if (cc == 66) {       // down arrow
      for(0 =>int i; i < 6; ++i) {
       o[i] =< f[i] =< c[i] =< dac;//env => dac;
       setMixLevel(i);
      }
    }
  }
   <<< "[mix]", mixcontrol, "[det]", detunecontrol >>>;
  if (cc == 65 || cc == 66) {
    if (cc == 66) {              // up arrow
      .025 +=> mixcontrol;
      if (mixcontrol > 1) 1 => mixcontrol;
      setMixLevels();
    } else if (cc == 65) {       // down arrow
      -.025 +=> mixcontrol;
      if (mixcontrol < 0) 0 => mixcontrol;
      setMixLevels();
    }
  } else if (cc == 67 || cc == 68) {
    if (cc == 68)     -.025 +=> detunecontrol;
    else if (cc == 67) .025 +=> detunecontrol;
    if (detunecontrol < 0) 0 => detunecontrol;
    if (detunecontrol >1) 1 => detunecontrol;
    detunecontrol => xd.amount;
    onDetune();
  }
 }


}

// ------------------- Polypoly -------------------


public class supersaws {
   2 => int nosc;
   supersaw @s[nosc];
   new supersaw[nosc]    @=> s;

   fun void doCmdKey(int o, int c) {
     for(0=>int i; i<nosc;++i) {
     s[i].doCmdKey(o, c);
    }
   }

   fun void triggerNote(int c) {
     for(0=>int i; i<nosc;++i) {
      i +1 *=> c => Std.mtof => float fl;
      s[i].trigger(fl);
     }
   }

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


while( true ) {
    kb => now;		// wait on kbd event

    while( kb.more() ) {
        kb.getchar() => int chr;
 <<< chr >>>;
        if (chr == 27 || chr == 59) {	// '^'
          kb.getchar();                 // we eat up the 91
          kb.getchar() => int d;
          s.doCmdKey(chr, d);
        } else {
          chr => Std.mtof => float f;
          s.trigger(f);
//            s.triggerNote(chr);
        }
    }
//    24::ms => now;
}
