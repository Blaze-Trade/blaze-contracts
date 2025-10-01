import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useState, useEffect } from "react";
import { useToast } from "@/components/ui/use-toast";
// Internal components
import { Header } from "@/components/Header";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { LabeledInput } from "@/components/ui/labeled-input";
import { ConfirmButton } from "@/components/ui/confirm-button";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
// Internal utils
import { aptosClient } from "@/utils/aptosClient";
import { convertAmountFromOnChainToHumanReadable, convertAmountFromHumanReadableToOnChain } from "@/utils/helpers";
// Entry functions
import { createQuest } from "@/entry-functions/create_quest";
import { joinQuest } from "@/entry-functions/join_quest";
import { selectPortfolio } from "@/entry-functions/select_portfolio";
import { declareWinner } from "@/entry-functions/declare_winner";
// View functions
import { getAllQuests, getUserParticipation, hasUserParticipated, getQuestParticipants, Quest, Participation } from "@/view-functions/quest";

export function QuestManagement() {
  const { account, signAndSubmitTransaction } = useWallet();
  const { toast } = useToast();

  // State for quest creation
  const [questName, setQuestName] = useState<string>("");
  const [entryFee, setEntryFee] = useState<string>("");
  const [buyInTime, setBuyInTime] = useState<string>("");
  const [resultTime, setResultTime] = useState<string>("");

  // State for portfolio selection
  const [selectedQuestId, setSelectedQuestId] = useState<number | null>(null);
  const [portfolioTokens, setPortfolioTokens] = useState<Array<{ address: string; amount: string }>>([]);
  const [winnerAddress, setWinnerAddress] = useState<string>("");

  // State for data
  const [quests, setQuests] = useState<Quest[]>([]);
  const [userParticipations, setUserParticipations] = useState<Map<number, Participation>>(new Map());
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  // Load quests on component mount
  useEffect(() => {
    loadQuests();
  }, []);

  // Load user participations when account changes
  useEffect(() => {
    if (account) {
      loadUserParticipations();
    }
  }, [account, quests]);

  const loadQuests = async () => {
    try {
      setLoading(true);
      const allQuests = await getAllQuests();
      setQuests(allQuests);
    } catch (error) {
      toast({
        variant: "destructive",
        title: "Error",
        description: `Failed to load quests: ${error}`,
      });
    } finally {
      setLoading(false);
    }
  };

  const loadUserParticipations = async () => {
    if (!account) return;

    try {
      const participations = new Map<number, Participation>();
      
      for (const quest of quests) {
        const hasParticipated = await hasUserParticipated(account.address, quest.quest_id);
        if (hasParticipated) {
          const participation = await getUserParticipation(account.address, quest.quest_id);
          participations.set(quest.quest_id, participation);
        }
      }
      
      setUserParticipations(participations);
    } catch (error) {
      console.error("Failed to load user participations:", error);
    }
  };

  const handleCreateQuest = async () => {
    try {
      if (!account) throw new Error("Connect wallet first");

      const response = await signAndSubmitTransaction(
        createQuest({
          name: questName,
          entryFee: convertAmountFromHumanReadableToOnChain(parseFloat(entryFee), 8), // APT has 8 decimals
          buyInTime: parseInt(buyInTime) * 60, // convert minutes to seconds
          resultTime: parseInt(resultTime) * 60, // convert minutes to seconds
        })
      );

      await aptosClient().waitForTransaction({
        transactionHash: response.hash,
      });

      toast({
        title: "Success",
        description: "Quest created successfully!",
      });

      // Reset form and reload quests
      setQuestName("");
      setEntryFee("");
      setBuyInTime("");
      setResultTime("");
      await loadQuests();
    } catch (error) {
      toast({
        variant: "destructive",
        title: "Error",
        description: `Failed to create quest: ${error}`,
      });
    }
  };

  const handleJoinQuest = async (questId: number) => {
    try {
      if (!account) throw new Error("Connect wallet first");

      const response = await signAndSubmitTransaction(
        joinQuest({ questId })
      );

      await aptosClient().waitForTransaction({
        transactionHash: response.hash,
      });

      toast({
        title: "Success",
        description: "Successfully joined quest!",
      });

      await loadQuests();
      await loadUserParticipations();
    } catch (error) {
      toast({
        variant: "destructive",
        title: "Error",
        description: `Failed to join quest: ${error}`,
      });
    }
  };

  const handleSelectPortfolio = async () => {
    try {
      if (!account || !selectedQuestId) throw new Error("Missing required data");

      const tokenAddresses = portfolioTokens.map(t => t.address);
      const amountsUsdc = portfolioTokens.map(t => convertAmountFromHumanReadableToOnChain(parseFloat(t.amount), 6)); // USDC has 6 decimals

      const response = await signAndSubmitTransaction(
        selectPortfolio({
          questId: selectedQuestId,
          tokenAddresses,
          amountsUsdc,
        })
      );

      await aptosClient().waitForTransaction({
        transactionHash: response.hash,
      });

      toast({
        title: "Success",
        description: "Portfolio selected successfully!",
      });

      // Reset portfolio selection
      setPortfolioTokens([]);
      setSelectedQuestId(null);
      await loadUserParticipations();
    } catch (error) {
      toast({
        variant: "destructive",
        title: "Error",
        description: `Failed to select portfolio: ${error}`,
      });
    }
  };

  const handleDeclareWinner = async (questId: number) => {
    try {
      if (!account) throw new Error("Connect wallet first");

      const response = await signAndSubmitTransaction(
        declareWinner({
          questId,
          winner: winnerAddress,
        })
      );

      await aptosClient().waitForTransaction({
        transactionHash: response.hash,
      });

      toast({
        title: "Success",
        description: "Winner declared successfully!",
      });

      setWinnerAddress("");
      await loadQuests();
    } catch (error) {
      toast({
        variant: "destructive",
        title: "Error",
        description: `Failed to declare winner: ${error}`,
      });
    }
  };

  const addPortfolioToken = () => {
    if (portfolioTokens.length < 5) {
      setPortfolioTokens([...portfolioTokens, { address: "", amount: "" }]);
    }
  };

  const removePortfolioToken = (index: number) => {
    const newTokens = portfolioTokens.filter((_, i) => i !== index);
    setPortfolioTokens(newTokens);
  };

  const updatePortfolioToken = (index: number, field: 'address' | 'amount', value: string) => {
    const newTokens = [...portfolioTokens];
    newTokens[index][field] = value;
    setPortfolioTokens(newTokens);
  };

  const getStatusBadge = (status: string) => {
    const variants = {
      Active: "default",
      Closed: "secondary",
      Completed: "outline",
      Cancelled: "destructive",
    } as const;

    return (
      <Badge variant={variants[status as keyof typeof variants] || "default"}>
        {status}
      </Badge>
    );
  };

  const formatTime = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleString();
  };

  const canJoinQuest = (quest: Quest) => {
    if (!account) return false;
    const hasParticipated = userParticipations.has(quest.quest_id);
    const currentTime = Math.floor(Date.now() / 1000);
    return quest.status === "Active" && !hasParticipated && currentTime < quest.buy_in_time;
  };

  const canSelectPortfolio = (quest: Quest) => {
    if (!account) return false;
    const participation = userParticipations.get(quest.quest_id);
    const currentTime = Math.floor(Date.now() / 1000);
    return participation && !participation.portfolio && currentTime < quest.buy_in_time;
  };

  const canDeclareWinner = (quest: Quest) => {
    if (!account) return false;
    const currentTime = Math.floor(Date.now() / 1000);
    return quest.status === "Active" && currentTime >= quest.result_time;
  };

  return (
    <>
      <Header />
      <div className="max-w-screen-xl mx-auto p-6">
        <div className="mb-8">
          <h1 className="text-3xl font-bold mb-2">Quest Management</h1>
          <p className="text-muted-foreground">
            Create and manage quests, join competitions, and declare winners
          </p>
        </div>

        <Tabs defaultValue="quests" className="space-y-6">
          <TabsList className="grid w-full grid-cols-4">
            <TabsTrigger value="quests">All Quests</TabsTrigger>
            <TabsTrigger value="create">Create Quest</TabsTrigger>
            <TabsTrigger value="portfolio">Select Portfolio</TabsTrigger>
            <TabsTrigger value="admin">Admin Actions</TabsTrigger>
          </TabsList>

          <TabsContent value="quests" className="space-y-4">
            <div className="flex justify-between items-center">
              <h2 className="text-2xl font-semibold">All Quests</h2>
              <Button onClick={loadQuests} disabled={loading}>
                {loading ? "Loading..." : "Refresh"}
              </Button>
            </div>

            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>ID</TableHead>
                  <TableHead>Name</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Entry Fee (APT)</TableHead>
                  <TableHead>Participants</TableHead>
                  <TableHead>Total Pool (APT)</TableHead>
                  <TableHead>Buy-in Deadline</TableHead>
                  <TableHead>Result Time</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {quests.map((quest) => (
                  <TableRow key={quest.quest_id}>
                    <TableCell className="font-medium">{quest.quest_id}</TableCell>
                    <TableCell>{quest.name}</TableCell>
                    <TableCell>{getStatusBadge(quest.status)}</TableCell>
                    <TableCell>{convertAmountFromOnChainToHumanReadable(quest.entry_fee, 8)}</TableCell>
                    <TableCell>{quest.participants.length}</TableCell>
                    <TableCell>{convertAmountFromOnChainToHumanReadable(quest.total_pool, 8)}</TableCell>
                    <TableCell>{formatTime(quest.buy_in_time)}</TableCell>
                    <TableCell>{formatTime(quest.result_time)}</TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        {canJoinQuest(quest) && (
                          <Button
                            size="sm"
                            onClick={() => handleJoinQuest(quest.quest_id)}
                          >
                            Join
                          </Button>
                        )}
                        {canSelectPortfolio(quest) && (
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => setSelectedQuestId(quest.quest_id)}
                          >
                            Select Portfolio
                          </Button>
                        )}
                        {canDeclareWinner(quest) && (
                          <Button
                            size="sm"
                            variant="destructive"
                            onClick={() => setSelectedQuestId(quest.quest_id)}
                          >
                            Declare Winner
                          </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TabsContent>

          <TabsContent value="create" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>Create New Quest</CardTitle>
                <CardDescription>
                  Create a new quest for users to participate in
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <LabeledInput
                  id="quest-name"
                  label="Quest Name"
                  placeholder="Enter quest name"
                  value={questName}
                  onChange={(e) => setQuestName(e.target.value)}
                  disabled={!account}
                />

                <LabeledInput
                  id="entry-fee"
                  label="Entry Fee (APT)"
                  placeholder="0.1"
                  type="number"
                  step="0.01"
                  value={entryFee}
                  onChange={(e) => setEntryFee(e.target.value)}
                  disabled={!account}
                />

                <LabeledInput
                  id="buy-in-time"
                  label="Buy-in Time (minutes from now)"
                  placeholder="60"
                  type="number"
                  value={buyInTime}
                  onChange={(e) => setBuyInTime(e.target.value)}
                  disabled={!account}
                />

                <LabeledInput
                  id="result-time"
                  label="Result Time (minutes from now)"
                  placeholder="120"
                  type="number"
                  value={resultTime}
                  onChange={(e) => setResultTime(e.target.value)}
                  disabled={!account}
                />

                <ConfirmButton
                  title="Create Quest"
                  onSubmit={handleCreateQuest}
                  disabled={!questName || !entryFee || !buyInTime || !resultTime || !account}
                  confirmMessage="Are you sure you want to create this quest?"
                />
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="portfolio" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>Select Portfolio</CardTitle>
                <CardDescription>
                  Choose 1-5 tokens for your quest portfolio
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                {selectedQuestId && (
                  <div className="p-4 bg-muted rounded-lg">
                    <p className="font-medium">Selected Quest: {quests.find(q => q.quest_id === selectedQuestId)?.name}</p>
                    <p className="text-sm text-muted-foreground">Quest ID: {selectedQuestId}</p>
                  </div>
                )}

                {portfolioTokens.map((token, index) => (
                  <div key={index} className="flex gap-4 items-end">
                    <div className="flex-1">
                      <Label htmlFor={`token-${index}`}>Token Address</Label>
                      <Input
                        id={`token-${index}`}
                        placeholder="0x..."
                        value={token.address}
                        onChange={(e) => updatePortfolioToken(index, 'address', e.target.value)}
                      />
                    </div>
                    <div className="flex-1">
                      <Label htmlFor={`amount-${index}`}>Amount (USDC)</Label>
                      <Input
                        id={`amount-${index}`}
                        placeholder="100"
                        type="number"
                        step="0.01"
                        value={token.amount}
                        onChange={(e) => updatePortfolioToken(index, 'amount', e.target.value)}
                      />
                    </div>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => removePortfolioToken(index)}
                    >
                      Remove
                    </Button>
                  </div>
                ))}

                {portfolioTokens.length < 5 && (
                  <Button variant="outline" onClick={addPortfolioToken}>
                    Add Token
                  </Button>
                )}

                <Separator />

                <ConfirmButton
                  title="Submit Portfolio"
                  onSubmit={handleSelectPortfolio}
                  disabled={!selectedQuestId || portfolioTokens.length === 0 || !account}
                  confirmMessage="Are you sure you want to submit this portfolio?"
                />
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="admin" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>Admin Actions</CardTitle>
                <CardDescription>
                  Declare winners for completed quests
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                {selectedQuestId && (
                  <div className="p-4 bg-muted rounded-lg">
                    <p className="font-medium">Selected Quest: {quests.find(q => q.quest_id === selectedQuestId)?.name}</p>
                    <p className="text-sm text-muted-foreground">Quest ID: {selectedQuestId}</p>
                  </div>
                )}

                <LabeledInput
                  id="winner-address"
                  label="Winner Address"
                  placeholder="0x..."
                  value={winnerAddress}
                  onChange={(e) => setWinnerAddress(e.target.value)}
                  disabled={!account}
                />

                <ConfirmButton
                  title="Declare Winner"
                  onSubmit={() => selectedQuestId && handleDeclareWinner(selectedQuestId)}
                  disabled={!selectedQuestId || !winnerAddress || !account}
                  confirmMessage="Are you sure you want to declare this winner?"
                />
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </>
  );
}
