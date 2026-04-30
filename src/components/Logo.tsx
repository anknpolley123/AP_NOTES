import React from 'react';

interface LogoProps {
  className?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
}

export default function Logo({ className = '', size = 'md' }: LogoProps) {
  const sizes = {
    sm: 'w-8 h-8',
    md: 'w-12 h-12',
    lg: 'w-24 h-24',
    xl: 'w-36 h-36'
  };

  return (
    <div className={`relative flex flex-col items-center justify-center ${className}`}>
      <div className={`${sizes[size]} relative flex items-center justify-center`}>
        {/* Dragon Head Logo - Professional Vector Style */}
        <svg 
          viewBox="0 0 100 100" 
          className="absolute inset-0 w-full h-full drop-shadow-[0_0_15px_rgba(239,68,68,0.4)]"
          fill="none" 
          stroke="currentColor" 
          strokeWidth="2"
        >
          {/* Main Head Structure */}
          <path 
            d="M20,50 C20,25 45,20 65,25 Q85,30 85,50 Q85,70 65,75 T25,70 Q20,65 20,50 Z" 
            className="text-red-600" 
            fill="currentColor" 
            fillOpacity="0.15" 
          />
          {/* Eye - Sharp & Intelligent */}
          <path d="M62,38 Q65,40 68,38" stroke="white" strokeWidth="1.5" />
          <circle cx="65" cy="42" r="2" fill="white" stroke="none" />
          
          {/* Horns / Spikes */}
          <path d="M45,22 Q50,5 60,15" className="text-red-500" />
          <path d="M35,30 Q35,15 45,22" className="text-red-500" strokeOpacity="0.5" />
          
          {/* Flame - Stylised Pulse */}
          <path 
            d="M85,50 L96,55 M85,53 L94,58" 
            strokeWidth="3" 
            strokeLinecap="round" 
            className="text-orange-500 animate-pulse" 
          />
          
          {/* Mouth / Detail */}
          <path d="M70,55 Q75,65 65,70" className="text-red-800" opacity="0.4" />
        </svg>
        
        {/* AP Text - Bold & Futuristic */}
        <div className="relative z-10 flex items-center justify-center pointer-events-none">
          <span className="font-black italic tracking-tighter text-white text-shadow-xl" style={{ fontSize: size === 'xl' ? '2.8rem' : '1.3rem' }}>
            AP
          </span>
        </div>
      </div>
      
      {size === 'xl' && (
        <div className="mt-4">
          <div className="text-[24px] font-black text-white italic tracking-tighter uppercase">AP_NOTES</div>
          <div className="text-[8px] font-black text-blue-500 tracking-[0.6em] uppercase opacity-60 text-center">Neural Workspace</div>
        </div>
      )}
    </div>
  );
}
