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
    xl: 'w-32 h-32'
  };

  return (
    <div className={`relative flex flex-col items-center justify-center ${className}`}>
      <div className={`${sizes[size]} relative flex items-center justify-center`}>
        {/* Improved Dragon Silhouette */}
        <svg 
          viewBox="0 0 100 100" 
          className="absolute inset-0 w-full h-full text-red-500 drop-shadow-[0_0_12px_rgba(239,68,68,0.5)]"
          fill="none" 
          stroke="currentColor" 
          strokeWidth="2"
        >
          <path d="M20,50 Q20,20 50,20 Q80,20 85,45 L95,50 L85,55 Q80,80 50,80 Q20,80 20,50" fill="currentColor" fillOpacity="0.15" />
          <path d="M85,50 L98,53" strokeWidth="4" strokeLinecap="round" className="animate-pulse" />
          <path d="M40,20 Q50,5 70,15" strokeWidth="1.5" opacity="0.4" />
          <path d="M25,75 Q15,85 20,95" strokeWidth="1.5" opacity="0.4" />
        </svg>
        
        {/* AP Text */}
        <span className="relative z-10 font-black italic tracking-tighter text-white drop-shadow-lg" style={{ fontSize: size === 'xl' ? '2.5rem' : '1.2rem' }}>
          AP
        </span>
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
