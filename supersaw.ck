// supersaw
// based on study by Adam Szabo
// https://www.nada.kth.se/utbildning/grukth/exjobb/rapportlistor/2010/rapporter10/szabo_adam_10131.pdf

// TODO:
//  handle midi messages
//  
// CONTROLS:
//  [left - right] => detune amount
//  [ up  - down ] => oscs mix
int device;
2 => device;

class NoteEvent extends Event
{
    int note;
    int velocity;
    float mix;
    float det;
}

NoteEvent on;

// array of ugen's handling each note
Event @ us[128];



class supersaw {
   static Gain   @c[7];  // six channel mixer [todo, curves]
   static SawOsc @o[7];  // six sawtooth oscs
   static HPF    @f;  // six hpfs
   new Gain[7]   @=> c;
   new HPF    @=> f;
   new SawOsc[7] @=> o;
   Detune xd;
   ADSR env;
   float mixcontrol, detunecontrol, mfreq;

   connect();
   fun void connect() {
     <<< "con" >>>;
     0.5 => detunecontrol => xd.det;		// initial amount of detuning
     0.5 => mixcontrol;		// initial oscillator mixing
     for(0 =>int i; i < 7; ++i) {
       o[i] => c[i] => f => dac;//env => dac;
       setMixLevel(i);
     }
   }

   fun void disconnect() {
     <<< "discon" >>>;
     for(0 =>int i; i < 7; ++i) {
       o[i] =< c[i] =< f =< dac;//env => dac;
     }
   }

   // computes the detuned frequency for each osc
   [ - 0.11002313,  - 0.06288439,- 0.01952356, 0.01991221,0.06216538,0.10745242] @=> float osc_offsets[];

   fun float dodetune(float x, int n) {
     if (n == 0)return x;
     //<<<  xd.output() >>>;
     return x+(osc_offsets[n-1] * 1 + xd.det());
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
     for(0 =>int i; i < 7; ++i) {
       dodetune(mfreq,i) => o[i].freq;
       o[i].freq() => float tmp;
       tmp => f.freq;               // adjust HPF
     }

   }

   fun void noteOff() {
     for(0 =>int i; i < 7; ++i) {
       0 => o[i].freq;
     }
   }

   fun void trigger(float freq) {
     <<< "triggering" >>>;
     1 => env.keyOn;
     env.set(.1::second,1::second,0.0,.1::second);
     freq => mfreq;
     for(0 =>int i; i < 7; ++i) {
       randphase()   => o[i].phase;
       dodetune(freq,i) => o[i].freq;
       freq  => f.freq;               // adjust HPF
     }
   }

   fun void setMixLevels() {
     for(0 =>int i; i < 7; ++i) {
       setMixLevel(i);
     }
   }
} // - end of supersaw class

.5 =>  float mixcontrol;
.5 =>  float detunecontrol;


 fun void doCmdKey(int oo, int cc) {
  if (cc == 65 || cc == 66) {
    if (cc == 66) {              // up arrow
      .025 +=> mixcontrol;
      if (mixcontrol > 1) 1 => mixcontrol;
      mixcontrol => on.mix;
      <<< "mix!" >>>;
      on.broadcast();
      me.yield();

    } else if (cc == 65) {       // down arrow
      -.025 +=> mixcontrol;
      if (mixcontrol < 0) 0 => mixcontrol;
      mixcontrol => on.mix;
      on.broadcast();
      me.yield();

    }
  } else if (cc == 67 || cc == 68) {
    if (cc == 68)     -.025 +=> detunecontrol;
    else if (cc == 67) .025 +=> detunecontrol;
    if (detunecontrol < 0) 0 => detunecontrol;
    if (detunecontrol >1) 1 => detunecontrol;
    detunecontrol => on.det;
    on.broadcast();
    me.yield();

  }
 }



fun void handler() // voice handler
{
  supersaw s;
  Event off;
  int note;

  while( true ) {
    on => now;
    on.note => note;
    on.det =>  s.xd.det;
    s.onDetune();
    on.mix => s.mixcontrol;
    s.setMixLevels();

    <<< "note" ,note >>>;
    s.connect();
    s.trigger(Std.mtof( note ));
    // on.velocity / 128.0 => something;
    off @=> us[note];
    off => now;
    null @=> us[note];
    //s.noteOff();
    s.disconnect();
  }
}

for( 0 => int i; i < 20; i++ ) spork ~ handler();



// ------------------- RUN LOOP -------------------
// TODO: use midi for keys
//  see examples/midi/polyfony.ck

//supersaw s;
KBHit kb;
MidiIn min;
MidiMsg msg;


if( !min.open( device ) ) me.exit();

// print out device that was opened
<<< "MIDI device:", min.num(), " -> ", min.name() >>>;


fun void kbHandler ( ) { while (true) {
    kb => now;          // wait on kbd event

    while( kb.more() ) {
        kb.getchar() => int chr;
        if (chr == 27 || chr == 59) {   // '^'
          kb.getchar();                 // we eat up the 91
          kb.getchar() => int d;
          doCmdKey(chr, d);
        } else {
          chr => on.note;
          on.signal();
          me.yield();
        }
    }
}}

fun void midiHandler() { while (true) {
        min => now;
        while (min.recv(msg)) {
          //<<< msg.data1, msg.data2, msg.data3 >>>;
          if((msg.data1 & 0xF0) == 0x90 && msg.data2 > 0) {
            if ( msg.data3 > 0 ) {
              <<< msg.data1, msg.data2, msg.data3 >>>;
              msg.data2 => on.note;
	      msg.data3 => on.velocity;
              on.signal();
              me.yield();
            } else {
              if( us[msg.data2] != null ) us[msg.data2].signal();
            }

          } else {if ((msg.data1 & 0xF1) == 0x90) {
	     us[msg.data2].signal();
          }}
        }
}}

//spork ~ midiHandler();
spork ~ kbHandler();

while( true ) {
	1::second => now;
}
