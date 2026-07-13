import Contact from "@/components/Contact";
import Fidelity from "@/components/Fidelity";
import Footer from "@/components/Footer";
import Hero from "@/components/Hero";
import HowItWorks from "@/components/HowItWorks";
import Install from "@/components/Install";
import LaminarFlow from "@/components/LaminarFlow";
import Languages from "@/components/Languages";
import MadeForWork from "@/components/MadeForWork";
import Manifesto from "@/components/Manifesto";
import Nav from "@/components/Nav";
import UnderTheHood from "@/components/UnderTheHood";
import WhyLocal from "@/components/WhyLocal";
import { getGitHubMeta } from "@/lib/github";

export const revalidate = 3600;

export default async function Home() {
  const { stars, releaseTag } = await getGitHubMeta();

  return (
    <>
      <Nav stars={stars} />
      <main>
        <Hero />
        <Fidelity />
        <Manifesto />
        <Languages />
        <MadeForWork />
        <LaminarFlow />
        <HowItWorks />
        <UnderTheHood releaseTag={releaseTag} />
        <WhyLocal />
        <Contact />
        <Install stars={stars} />
      </main>
      <Footer />
    </>
  );
}
