// Port of CCloth::simulate (0x436e80) and the particle solver (0x4366f0) from nocturne.exe.
// Root stopped, no wind. Locked vertices static. Collision bones are estimated from the coat shape.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
typedef struct { float x,y,z; } V;
#define MAXP 256
#define MAXL 15
typedef struct { V p,v,start,base,prev; int locked,nl,link[MAXL]; float rest[MAXL]; int hit; } P;
typedef struct { V t; V rx,ry,rz; float r0,r1,len; } B;
static P ps[MAXP]; static int np, order[MAXP];
static B bs[16]; static int nb;
static float invDt, spring, dampen, bodyFric;
// options
static int optSqrt=0, optInv=0, optNoHitVel=0, optStep=0, optDampNorm=0, optSort=0;
static double optPush=1.05; static float optSleep=0; static double optSway=0;
static inline float fsq(float x){ union{float f;int32_t i;}u; u.f=x; u.i=(u.i>>1)+0x1fc00000; return u.f; }
static inline float fis(float x){ union{float f;int32_t i;}u; u.f=x; u.i=0x5f400000-(u.i>>1); return u.f; }
static inline float SQ(float x){ return optSqrt? sqrtf(x):fsq(x); }
static inline float IS(float x){ return optInv? (x>0?1.f/sqrtf(x):0.f):fis(x); }
static inline float dot(V a,V b){ return a.x*b.x+a.y*b.y+a.z*b.z; }
static void solve(P*a){
  for(int i=0;i<a->nl;i++){
    P*q=&ps[a->link[i]]; V d={a->p.x-q->p.x,a->p.y-q->p.y,a->p.z-q->p.z};
    float L=SQ(dot(d,d)), r=a->rest[i];
    if(L>r){ float e=L-r,s=e/L; V c={d.x*s,d.y*s,d.z*s};
      a->p.x-=c.x;a->p.y-=c.y;a->p.z-=c.z; a->v.x-=c.x*invDt;a->v.y-=c.y*invDt;a->v.z-=c.z*invDt; }
    if(L<r){ float e=r-L,s=e/L*spring; V c={d.x*s,d.y*s,d.z*s};
      a->p.x+=c.x;a->p.y+=c.y;a->p.z+=c.z; a->v.x+=c.x*invDt;a->v.y+=c.y*invDt;a->v.z+=c.z*invDt; }
  }
  for(int b=0;b<nb;b++){
    B*B_=&bs[b]; V d={a->p.x-B_->t.x,a->p.y-B_->t.y,a->p.z-B_->t.z};
    float z=dot(d,B_->rz); if(z<0||z>B_->len) continue;
    float x=dot(d,B_->rx), y=dot(d,B_->ry);
    float a0=x/B_->r0,a1=y/B_->r1; float R=SQ(a0*a0+a1*a1);
    if(!(R<1.f)) continue;
    float n=IS(x*x+y*y); float nx=x*n*B_->r0*optPush, ny=y*n*B_->r1*optPush;
    V w={B_->t.x+B_->rx.x*nx+B_->ry.x*ny+B_->rz.x*z, B_->t.y+B_->rx.y*nx+B_->ry.y*ny+B_->rz.y*z, B_->t.z+B_->rx.z*nx+B_->ry.z*ny+B_->rz.z*z};
    V c={w.x-a->p.x,w.y-a->p.y,w.z-a->p.z}; a->p=w;
    if(!optNoHitVel){ a->v.x+=c.x*invDt;a->v.y+=c.y*invDt;a->v.z+=c.z*invDt; }
    a->hit=1;
  }
}
static void sim(float dt,float g){
  if(dt<0.01f) dt=0.01f;
  invDt=1.f/dt;
  float dm=dampen, fr=bodyFric;
  if(optDampNorm){ dm=pow(dampen,dt*30.f); fr=pow(bodyFric,dt*30.f); }
  for(int i=0;i<np;i++){ps[i].hit=0;ps[i].prev=ps[i].p;}
  for(int k=0;k<np;k++){ P*a=&ps[order[k]]; if(a->locked) continue;
    a->v.x*=dm;a->v.y*=dm;a->v.z*=dm;
    a->v.y-=g*dt;
    a->p.x+=a->v.x*dt;a->p.y+=a->v.y*dt;a->p.z+=a->v.z*dt;
    solve(a);
  }
  for(int s=0;s<5;s++) for(int k=0;k<np;k++){ P*a=&ps[order[k]]; if(!a->locked) solve(a); }
  for(int k=0;k<np;k++){ P*a=&ps[order[k]]; if(a->hit){a->v.x*=fr;a->v.y*=fr;a->v.z*=fr;} }
  if(optSleep>0){ float lim=optSleep*dt; lim*=lim;
    for(int i=0;i<np;i++){ P*a=&ps[i]; if(a->locked)continue; V d={a->p.x-a->prev.x,a->p.y-a->prev.y,a->p.z-a->prev.z};
      if(dot(d,d)<lim){a->p=a->prev;a->v=(V){0,0,0};} } }
}
static void addb(V a,V b,float r0,float r1){
  B*B_=&bs[nb++]; B_->t=a; V d={b.x-a.x,b.y-a.y,b.z-a.z}; float l=sqrtf(dot(d,d));
  B_->len=l; B_->rz=(V){d.x/l,d.y/l,d.z/l}; V up={1,0,0};
  V x={up.x-B_->rz.x*dot(up,B_->rz),up.y-B_->rz.y*dot(up,B_->rz),up.z-B_->rz.z*dot(up,B_->rz)};
  float m=sqrtf(dot(x,x)); B_->rx=(V){x.x/m,x.y/m,x.z/m};
  V z=B_->rz,X=B_->rx; B_->ry=(V){z.y*X.z-z.z*X.y,z.z*X.x-z.x*X.z,z.x*X.y-z.y*X.x};
  B_->r0=r0;B_->r1=r1;
}
static int cmpY(const void*a,const void*b){ float p=ps[*(int*)a].start.y,q=ps[*(int*)b].start.y;
  float s=optSort?-1:1; return p<q?(int)s:(p>q?(int)-s:0); }
static void load(void){
  FILE*f=fopen("strcoat.kfm","r"); char l[512]; int st=0,nv=0,npoly=0,idx=0;
  static int edges[4096][2]; int ne=0;
  while(fgets(l,512,f)){
    if(!strncmp(l,"// vertex list",14)){st=1;idx=0;continue;}
    if(!strncmp(l,"// poly list",12)){st=2;continue;}
    if(!strncmp(l,"// texture",10))break;
    if(!strncmp(l,"//",2))continue;
    if(st==1){int x,y,z; if(sscanf(l,"%d,%d,%d",&x,&y,&z)==3){ps[idx].start=(V){x/256.f,y/256.f,z/256.f};ps[idx].p=ps[idx].start;idx++;}}
    if(st==2){int t,n; char*c=l; sscanf(c,"%d,%d",&t,&n); c=strchr(c,',')+1; c=strchr(c,',')+1;
      int vi[8]; for(int i=0;i<n;i++){vi[i]=atoi(c); for(int j=0;j<3;j++){c=strchr(c,',');if(!c)break;c++;}}
      for(int i=0;i<n;i++){edges[ne][0]=vi[i];edges[ne][1]=vi[(i+1)%n];ne++;edges[ne][0]=vi[(i+1)%n];edges[ne][1]=vi[i];ne++;}
      npoly++; }
  }
  fclose(f); np=idx;
  for(int i=0;i<np;i++){ps[i].locked=i<17;ps[i].nl=0;}
  for(int e=0;e<ne;e++){int a=edges[e][0],b=edges[e][1]; P*A=&ps[a]; int dup=0;
    for(int i=0;i<A->nl;i++) if(A->link[i]==b) dup=1;
    if(dup||A->start.y>ps[b].start.y) continue;
    if(A->nl>=MAXL) {puts("too many links");continue;}
    V d={A->start.x-ps[b].start.x,A->start.y-ps[b].start.y,A->start.z-ps[b].start.z};
    A->rest[A->nl]=sqrtf(dot(d,d)); A->link[A->nl++]=b; }
  for(int i=0;i<np;i++) order[i]=i;
  qsort(order,np,sizeof(int),cmpY);
}
static void reset(void){ for(int i=0;i<np;i++){ps[i].p=ps[i].start;ps[i].v=(V){0,0,0};ps[i].hit=0;} }
int main(int argc,char**argv){
  float g=32,fps=60; int bodies=1; double breathe=0;
  dampen=.95f;spring=.025f;bodyFric=.5f;
  for(int i=1;i<argc;i++){ char*a=argv[i];
    if(!strncmp(a,"fps=",4))fps=atof(a+4); else if(!strcmp(a,"sqrt"))optSqrt=1; else if(!strcmp(a,"inv"))optInv=1;
    else if(!strncmp(a,"push=",5))optPush=atof(a+5); else if(!strcmp(a,"nobodies"))bodies=0;
    else if(!strcmp(a,"nohitvel"))optNoHitVel=1; else if(!strcmp(a,"dampnorm"))optDampNorm=1;
    else if(!strncmp(a,"step=",5))optStep=atoi(a+5); else if(!strcmp(a,"sortup"))optSort=1;
    else if(!strncmp(a,"sleep=",6))optSleep=atof(a+6); else if(!strncmp(a,"sway=",5))optSway=atof(a+5);
    else if(!strncmp(a,"breathe=",8))breathe=atof(a+8); }
  load();
  if(bodies){ // estimated pose, values from STRCOAT.CTH radii
    addb((V){0,2.6f,0},(V){0,3.4f,0},.6f,.5f);    // Pelvis
    addb((V){0,3.3f,0},(V){0,3.9f,0},.5f,.52f);   // Spine
    addb((V){0,3.8f,0},(V){0,4.7f,0},.63f,.45f);  // Spine2
    addb((V){.3f,2.8f,0},(V){.35f,1.5f,0},.4f,.4f);  // L Thigh
    addb((V){.35f,1.5f,0},(V){.35f,.2f,0},.4f,.4f);  // L Calf
    addb((V){-.3f,2.8f,0},(V){-.35f,1.5f,0},.4f,.4f);
    addb((V){-.35f,1.5f,0},(V){-.35f,.2f,0},.4f,.4f);
  }
  reset();
  B base[16]; memcpy(base,bs,sizeof bs);
  double t=0; double frame=1.0/fps; double acc=0; int ms=0,lastms=0;
  int settle=(int)(30*fps), meas=(int)(30*fps);
  static V mn[MAXP],mx[MAXP],pr[MAXP]; double spd=0; long cnt=0;
  for(int f=0;f<settle+meas;f++){
    t+=frame; ms=(int)floor(t*1000); float dt=(ms-lastms)/1000.f; lastms=ms;
    if(optSway>0){ float ox=optSway*sin(t*2*3.14159265*1.5); for(int b=0;b<nb;b++){bs[b].t=base[b].t;bs[b].t.x+=ox;} for(int i=0;i<np;i++) if(ps[i].locked) ps[i].p.x=ps[i].start.x+ox; }
    if(breathe>0){ float ox=breathe*sin(t*2*3.14159265*0.3); for(int b=0;b<nb;b++){bs[b].t=base[b].t;bs[b].t.z+=ox;} }
    if(optStep>0){ acc+=dt; float h=1.f/optStep; int n=0; while(acc>=h&&n<4){ sim(h,g); acc-=h; n++; } }
    else sim(dt,g);
    if(f==settle){ for(int i=0;i<np;i++){mn[i]=mx[i]=pr[i]=ps[i].p;} }
    if(f>settle){ for(int i=0;i<np;i++){ V p=ps[i].p;
        if(p.x<mn[i].x)mn[i].x=p.x; if(p.y<mn[i].y)mn[i].y=p.y; if(p.z<mn[i].z)mn[i].z=p.z;
        if(p.x>mx[i].x)mx[i].x=p.x; if(p.y>mx[i].y)mx[i].y=p.y; if(p.z>mx[i].z)mx[i].z=p.z;
        if(!ps[i].locked){ V d={p.x-pr[i].x,p.y-pr[i].y,p.z-pr[i].z}; spd+=sqrtf(dot(d,d))/frame; cnt++; }
        pr[i]=p; } }
  }
  double rmax=0,ravg=0; int bad=0;
  for(int i=0;i<np;i++){ double dx=mx[i].x-mn[i].x,dy=mx[i].y-mn[i].y,dz=mx[i].z-mn[i].z; double r=sqrt(dx*dx+dy*dy+dz*dz); if(r>rmax)rmax=r; ravg+=r; if(!isfinite(r))bad++; }
  double stretch=0; for(int i=0;i<np;i++) for(int k=0;k<ps[i].nl;k++){ V d={ps[i].p.x-ps[ps[i].link[k]].p.x,ps[i].p.y-ps[ps[i].link[k]].p.y,ps[i].p.z-ps[ps[i].link[k]].p.z}; double e=fabs(sqrt(dot(d,d))/ps[i].rest[k]-1); if(e>stretch)stretch=e; }
  printf("mean_speed %.4f ft/s  mean_range %.4f ft  max_range %.4f ft  max_link_err %.1f%%  bad %d\n",spd/cnt,ravg/np,rmax,stretch*100,bad);
  return 0;
}
